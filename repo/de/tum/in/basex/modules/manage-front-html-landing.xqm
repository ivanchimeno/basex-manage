module namespace m = 'http://in.tum.de/basex/modules/manage-front-html-landing';

import module namespace file = 'http://expath.org/ns/file';
import module namespace map = 'http://www.w3.org/2005/xpath-functions/map';
(: Import frontend modules :)
import module namespace h = 'http://in.tum.de/basex/modules/manage-front-html';

(: Import backend modules :)
import module namespace ds = 'http://in.tum.de/basex/modules/manage-back-settings';
import module namespace duf = 'http://in.tum.de/basex/modules/manage-back-file';
import module namespace dux = 'http://in.tum.de/basex/modules/manage-back-xml';
import module namespace mbr = 'http://in.tum.de/basex/modules/manage-back-run';
import module namespace mberr = 'http://in.tum.de/basex/modules/manage-back-error';
import module namespace mbi = 'http://in.tum.de/basex/modules/manage-back-import';


(:~ Creates the directory structure of the component
    and generates an HTML table containing a list of web
    applications that have been imported.
:)
declare
function m:display-webapp-listing-table($BasexHomePath as xs:string)  {
  (: Create the directory structure for the component :)
  let $i := m:init-component-structure($BasexHomePath)
  let $error := mberr:has-error($i)
  return (
    (: Generate an HTML table containing error information :)
    if ($error) then (
      <p>
      { 
        h:gen-error-table(
          $i,
          "An error has occured while initializing the directory structure of component:")
      }
      </p>
    )
    else m:gen-webapp-listing-table($BasexHomePath)
  )
};

(:~ Attempts to generate an HTML table of web applications that have
    been important. In case of error, an error table will be generated.
:)
declare
%private
function m:gen-webapp-listing-table($BasexHomePath as xs:string) {
  (: Attempt to retrieve the contains of the webapp-listing.xml file. :)
  let $i := ds:get-webapp-listing-contents($BasexHomePath)
  let $error := not(xs:boolean($i//Success))
  return (
    (: Generate an HTML table containing error information in case
       an error has occured. :)
    if ($error) then (
      <p>
      {h:gen-error-table($i,"An error has occured while retrieving imported web applications:")}
      </p>
    ) else (
      <div>
        <p>The table below depicts all currently installed applications on this BaseX instance:</p>
        <p><a href='manage'>[Refresh]</a></p>
        <table>
          <tr>
            <th>Application Name</th>
            <th>Author</th>
            <th>Status</th>
            <th>Actions</th>
          </tr>
        {
          for $x in $i//WebAppSettings return (
            let $aState := $x//AppState
            let $aId := xs:string($x/@appIdentifier)

            let $appStateColor := (
              if (compare($aState, "active"))
              then  "red" else  "green"
            )

            let $runButtonText := (
              if (compare($aState, "active"))
              then "Enable" else "Disable"
            )

            let $sImg := (
              if (compare($aState, "active"))
              then <img width="24" height="24" src="manage/static/enable.svg" title="Run the application" align="left" />
              else <img width="24" height="24" src="manage/static/disable.svg" title="Disable the applicaiton" align="left"/>
            )

            return (
              <tr>
                <td>{
                  if (compare($aState, "inactive")) 
                  then <a href="{$x//EntryUrl}">{$x//AppName}</a>
                  else $x//AppName
                  }</td>
                <td>{$x//Author}</td>
                <td><font color="{$appStateColor}">{$x//AppState}</font></td>
                <td>
                  <div id="actions">
                  <a href="manage-sw?aId={$aId}&amp;aState={$aState}">{$sImg}</a>
                  <a href="manage-remove?appIds={$aId}"><img width="24" height="24" src="manage/static/delete.svg" title="Delete application..." align="left" 
                    onclick="return confirm('Are you sure you want to delete application?')"/></a>
                  </div>
                </td>
              </tr> 
            )
          ) 
        }
        </table>
      </div>
    )
  )
};

(:~ This function accomplishes a first time setup for the deploy component by
 :  creating the required directories and files if they don't already exist. 
:)
declare
%private
function m:init-component-structure($baseXHomePath as xs:string) as element() {
  try {
    (: Create directory structure of the component by first
       saving all required paths and then creating the directories :)
    let $dPath := ds:manage-dir-path($baseXHomePath)
    let $ePath := ds:exports-dir-path($baseXHomePath)
    let $iPath := ds:imports-dir-path($baseXHomePath)
    let $sPath := ds:settings-dir-path($baseXHomePath)
    let $tPath := ds:tmp-dir-path($baseXHomePath)

    return dux:results((
      (: Create the directory structure required by the 
         manage component. :)
      duf:create-dir($dPath),
      duf:create-dir($ePath),
      duf:create-dir($iPath),
      duf:create-dir($sPath),
      duf:create-dir($tPath),

      (: Create an .ignore file inside tmp directory
         because it may contain restxq xquery code that 
         shouldn't be executed by the server :)
      duf:create-ignore-file($tPath),

      (: Generate default settings xml file and an empty
         webapp listing file. :)
      m:init-deploy-settings($baseXHomePath, $sPath),
      m:init-webapp-listing($sPath),

      (: Check if an application has been created and
         assign it as a default application  :)
      mbr:detect-default-app($baseXHomePath)//Result,
      mbi:restore-webapp-listing($baseXHomePath)//Result
    ))
  } catch * {
    dux:error($err:code, $err:description, $err:module)
  }
};

(:~ Generates the default settings.xml file required by the BaseX management component,
    and saves it to the directory specified in $path (if it does not already exist).

    The settings file copies values from the BaseX configuration file (.basex) that is 
    located inside the directory specified inside $baseXHomePath.
:)
declare
%private
function m:init-deploy-settings($baseXHomePath as xs:string, $path as xs:string) 
as element() {
  let $destFile := duf:append-to-path($path, "settings.xml")
  let $config := ds:from-basex-config(duf:append-to-path($baseXHomePath, ".basex"))
  return (
    if (duf:is-xml($config)) then $config
    else if(file:exists($destFile)) 
      then dux:result($destFile || " already exists.")
    else (
      (: Retrieve template of settings file and fill elements
         with the respective options used by BaseX. :)
      copy $x := dux:gen-deploy-settings()
      modify (
        for $xx in $x//DbPath 
          return replace value of node $xx with map:get($config,"DBPATH"),
        
        for $xx in $x//RepoPath 
          return replace value of node $xx with map:get($config,"REPOPATH"),

        (: Use WEBPATH if RESTXQPATH is empty. If RESTXQPATH is relative
           concatenate it to WEBPATH. :)
        for $xx in $x//RestXQPath 
          return replace value of node $xx with (
            let $r := map:get($config, "RESTXQPATH")
            return duf:append-to-path(
              if (file:is-absolute($r)) then $r else
              if (string-length($r)>0) then duf:append-to-path(map:get($config, "WEBPATH"), $r)
              else map:get($config,"WEBPATH"),
              "restxq"
            )
          ),

        (: Default static directory will be WEBPATH/static :)
        for $xx in $x//WebStaticPath 
          return replace value of node $xx with duf:append-to-path(
            map:get($config,"WEBPATH"), 
            "static"
          )
      )
      return duf:write-xml($destFile, $x)
    )
  )
};

(:~ Generates the default webapp-listing.xml file required by the BaseX management component
    and saves it to the directory specified in $path (if it does not already exist).
:)
declare
%private
function m:init-webapp-listing($path as xs:string) as element() {
  let $destFile := duf:append-to-path($path, "webapp-listing.xml")
  return (
    if (file:exists($destFile)) then (
      dux:result($destFile || " already exists.")
    ) else (
        (: The default xml file that contains web app listing :)
        let $xml := dux:gen-webapp-listing()
        return duf:write-xml($destFile, $xml)
    )
  )
};
