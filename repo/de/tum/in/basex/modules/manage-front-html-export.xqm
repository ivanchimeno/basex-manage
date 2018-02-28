module namespace m = 'http://in.tum.de/basex/modules/manage-front-html-export';


(: Import frontend modules :)
import module namespace h = 'http://in.tum.de/basex/modules/manage-front-html';

(: Import backend modules :)
import module namespace mbs = 'http://in.tum.de/basex/modules/manage-back-settings';
import module namespace de = 'http://in.tum.de/basex/modules/manage-back-export';
import module namespace dux = 'http://in.tum.de/basex/modules/manage-back-xml';
import module namespace mberr = 'http://in.tum.de/basex/modules/manage-back-error';
import module namespace mbd = 'http://in.tum.de/basex/modules/manage-back-db';
import module namespace mbrep = 'http://in.tum.de/basex/modules/manage-back-repository';

(:
    Returns an HTML page that displays information to user user about
    exporting an application.
:)
declare
function m:export-landing($BasexHomePath as xs:string) {
  let $settings := mbs:get-settings-contents($BasexHomePath)
  return (
    h:html("Export",
      <div>
        <br/>
        <h2>Export your BaseX Web Application</h2>
        <p><a href='export'>Exporting</a> a web application via this tool will allow you to <a href='manage-import'>import</a> your project onto another system or BaseX instance.</p>
        <br/>
        <h3>Export Settings</h3>
        {
          if (mberr:has-error($settings)) then
            h:gen-error-table(
              $settings, 
              "There was an error while reading the settings.xml file:"
            )
          else m:paths-table($settings)
        }
        <br/>
        <h3>Web Application Settings</h3>
        <p>Please fill out the following information about the web application you would like to export.<br/></p>
        {
          if (mberr:has-error($settings)) then
            h:gen-error-table(
              $settings, 
              "There was an error while reading the settings.xml file:"
            )
          else m:export-form($settings)
          
        }
      </div>
    )
  )
};

(: 
    Attempts to export the web application. If successful, the function
    will return an XML file containing information about the exported
    application.
:)
declare 
function m:export-application(
  $BasexHomePath as xs:string, 
  $appName as xs:string, 
  $appAuthor as xs:string, 
  $appEntryUrl as xs:string, 
  $appDatabases as xs:string*,
  $appPackages as xs:string*
) 
{ 
  (: Generate XML file based on specified paramters
     which will then be used to export application. :)
  let $ex := m:to-xml(
    $appName, 
    $appAuthor, 
    $appEntryUrl, 
    $appDatabases,
    $appPackages
  )

  let $s := mbs:get-settings-contents($BasexHomePath)
  return (
    if (mberr:has-error($s)) then $s else (
      (: Export application and return HMTL displaying the
         results. :)
      h:html("Export",
        m:export-complete(
          $BasexHomePath,
          de:export-xproject(
            $BasexHomePath,
            $s//ExportSettings,
            $ex
          )
        )
      )
    )
  )
};

(:
    Returns an HTML page displaying the results coming from the
    export-application() function.
:)
declare
%private
function m:export-complete($BasexHomePath as xs:string, $result as element()) {
  if (mberr:has-error($result)) then 
    h:gen-error-table(
      $result, 
      "An error has occured while exporting the application:")
  else (
    <div>
      <h3>Export Complete!</h3>
      <p>Your web application has been successfully exported. You can find it at: <br/><code>{mbs:exports-dir-path($BasexHomePath)}</code></p>
      <p>The table below depicts information about the exported web application:</p>
      <table>
        <tr>
          <th>Application Name</th>
          <th>Author</th>
          <th>Application Url</th>
        </tr>
        <tr>
          <td>{$result//AppName}</td>
          <td>{$result//Author}</td>
          <td><a href="{$result//EntryUrl}">{$result//EntryUrl}</a></td>
        </tr>
        <tr>
          <th>Databases</th>
          <th>Filename</th>
          <th></th>
        </tr>
        <tr>
          <td><ul>{for $x in $result//Database return <li>{$x}</li>}</ul></td>
          <td>{xs:string($result//WebAppSettings/@appIdentifier) || ".manage"}</td>
          <td></td>
        </tr>
      </table>
    </div>
  )
};

(:
    Returns an XML element based on the contents
    of the specified parameters.
:)
declare
%private
function m:to-xml(
  $appName as xs:string,  
  $appAuthor as xs:string, 
  $appEntryUrl as xs:string, 
  $appDatabases as xs:string*,
  $appPackages as xs:string*
) as element() {
  copy $sXml := dux:gen-app-settings()
  modify (
    replace value of node $sXml//AppName with $appName,
    replace value of node $sXml//Author with $appAuthor,
    replace value of node $sXml//EntryUrl with $appEntryUrl,
    replace node $sXml//Databases with (
      <Databases>{
        for $d in $appDatabases 
        return <Database>{$d}</Database>}
      </Databases>
    ),
    replace node $sXml//Packages with (
      <Packages>{
        for $d in $appPackages 
        return <Package>{$d}</Package>
      }</Packages>
    )
  )
  return ($sXml)
};

(:
    Returns an HTML table depicting the web components
    that will be exported and their directory paths.
:)
declare
%private
function m:paths-table($settings as element()) {
  <div>
    <p>The following table depicts all components that will be exported:</p>
    <table>
      <tr>
        <td><b>Component</b></td>
        <td><b>Path</b></td>
      </tr>
      <tr>
        <td>DbPath (Databases)</td>
        <td><code>{$settings//ExportSettings/DbPath}</code></td>
      </tr>
      <tr>
        <td>RepoPath (Repositories)</td>
        <td><code>{$settings//ExportSettings/RepoPath}</code></td>
      </tr>
      <tr>
        <td>WebStaticPath (static folder)</td>
        <td><code>{$settings//ExportSettings/WebStaticPath}</code></td>
      </tr>
      <tr>
        <td>RestXQPath (XQuery, RestXQ folder)</td>
        <td><code>{$settings//ExportSettings/RestXQPath}</code></td>
      </tr>
    </table>
    <br/>
    <p>If you would like to change these paths, please edit the <code>settings.xml</code> file inside the <code>manage</code> directory which is available at <code>[BASEX HOME]/manage/settings/</code>.</p>
    <p>Please <a href='manage-export'>refresh</a> this page once changes have been made.</p>
  </div>
};

(:~ Generates an HTML form that contains all required fields
    that the user needs to fill out before exporting the application.
    The form sends a POST request to the /export-project/ URL.
:)
declare
%private
function m:export-form($settings as element()) {
  <div id="export-form">
    <form action="manage-export" method="POST" enctype="multipart/form-data">
      <fieldset>
        <label for="appName">Application Name</label>
        <input type="text" id="appName" name="appName" placeholder="Your application name..."/>
        <label for="appAuthor">Author</label>
        <input type="text" id="appAuthor" name="appAuthor" placeholder="The author of the application..."/>
        <label for="appEntryUrl">Application Entry URL (relative URL that points to the landing page of your application)</label>
        <input type="text" id="appEntryUrl" name="appEntryUrl" placeholder="/UrlToApp/"/>
      </fieldset>
      <br/>
      {
        (: Insert form component that will list the databases :)
        m:gen-database-listing-html(),
        m:gen-repository-listing-html($settings//ExportSettings/RepoPath)
      }
      <input id="form-button" type="submit" value="Export"/>
    </form>
  </div>
};

(:~ Generates a HTML component that contains a listing
    of databases installed on the BaseX system. If an error has 
    occured, an HTML table will be generated cotanining error-related
    information.
:)
declare
%private
function m:gen-database-listing-html() {
  (: Get database listings that will be available for the 
     user to choose. :)
  let $dbListing := mbd:list-db()
  return (
    if (mberr:has-error($dbListing)) then (
      h:gen-error-table(
        $dbListing, 
        "An error has occured while retrieving databases:")
    ) else (
      <fieldset>
        Select the databases you would like to export (hold down CTRL for multiple selection):
        <br/>
        <select name="appDatabases" size="{$dbListing//Databases/@count}" 
          multiple="multiple">
          {
            for $db in $dbListing//Database
            return (<option value="{$db}" >{$db}</option>)
          }
        </select>
      </fieldset>
    )
  )
};

declare
%private
function m:gen-repository-listing-html($repoPath as xs:string) {
  let $pkgListing := mbrep:installed-repos($repoPath)
  return (
    if (mberr:has-error($pkgListing)) then (
      h:gen-error-table(
        $pkgListing,
        "An error has occured while retrieving repository packages:"
      )
    ) else (
      <div>
      <br />
      <fieldset>
        Select the repository packages you would like to export (hold down CTRL for multiple selection):
        <br/>
        <select name="appPackages" size="{$pkgListing//Packages/@count}" multiple="multiple">
        {
          for $p in $pkgListing//Package
          return <option value="{$p/@path}">{$p}</option>
        }
        </select>
      </fieldset>
      </div>
    )
  )
};
