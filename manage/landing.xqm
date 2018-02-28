module namespace page = 'http://basex.org/modules/web-page';

import module namespace web = 'http://basex.org/modules/web';
import module namespace file = 'http://expath.org/ns/file';
import module namespace fetch = 'http://basex.org/modules/fetch';

import module namespace mfh = 'http://in.tum.de/basex/modules/manage-front-html';
import module namespace mfl = 'http://in.tum.de/basex/modules/manage-front-html-landing';
import module namespace mfe ='http://in.tum.de/basex/modules/manage-front-html-export';
import module namespace mfi = 'http://in.tum.de/basex/modules/manage-front-html-import';
import module namespace mfr = 'http://in.tum.de/basex/modules/manage-front-html-remove';

import module namespace mberr = 'http://in.tum.de/basex/modules/manage-back-error';
import module namespace mbf = 'http://in.tum.de/basex/modules/manage-back-file';
import module namespace mbs = 'http://in.tum.de/basex/modules/manage-back-settings';
import module namespace mbx = 'http://in.tum.de/basex/modules/manage-back-xml';
import module namespace mbr = 'http://in.tum.de/basex/modules/manage-back-run';


(:~
 : This function generates the landing page of the BaseX
 : component.
 : @return HTML page
 :)
declare
%rest:path("manage")
%output:method("xhtml")
%output:omit-xml-declaration("yes")
%output:doctype-public("-//W3C//DTD XHTML 1.0 Transitional//EN")
%output:doctype-system("http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd")
function page:manage() 
as element(Q{http://www.w3.org/1999/xhtml}html)
{
  let $content := (
    <div>
      <br/>
      <h2>Manage Your BaseX Web Applications</h2>
      <p>Welcome! This component lets your manage web applications that have been installed into this BaseX instance.
         If you would like to view and manage your web applications, <a href='manage-export'>export</a> them and <a href='manage-import'>import</a> them into the 
        system via this tool.
      </p>

      <br/>
      <h3>Export an Application</h3>
      <p><a href='manage-export'>Exporting</a> a web application via this tool will allow you to <a href='manage-import'>import</a> your project onto another system or BaseX instance.</p>
      <form action="manage-export">
        <input type="submit" value="Export Application" />
      </form>

      <br />
      <h3>Import an Application</h3>
      <p><a href='manage-import'>Import</a> an existing application into this BaseX instance if you would like to run or manage it. Note that the application to <a href='manage-import'>import</a> has to be an application that has been <b>exported using this tool</b>.</p>
      <form action="manage-import">
        <input type="submit" value="Import Application" />
      </form>

      <br/>
      <h3>Remove Applications</h3>
      <p>Select imported web applications to remove from this BaseX instance.</p>
      <form action="manage-remove">
        <input type="submit" value="Remove Applications" />
      </form>
      <br />
      <h3>Project Listings:</h3>
      {
        try {
          (: Attempt to read BaseX home directory from file
             and retrieve project listing 
          :)
          mfl:display-webapp-listing-table(page:BasexHomePath())
        } catch * {
          mfh:gen-error-table(
            mbx:error($err:code, $err:description, $err:module), 
            "An error has occured while attempting to read the landing-settings.xml file: ")
        }
      }
      <hr/>
      </div>
  )

  return mfh:html("Applications", $content)
};

(:
    Swap operation that is executed when an application
    is enabled or disabled.
:)
declare
%rest:path("/manage-sw")
%rest:query-param("aId", "{$appIdentifier}", "")
%rest:query-param("aState", "{$appState}", "")
function page:manage-sw($appIdentifier as xs:string, $appState as xs:string) {
  let $c := mberr:get-result(
    if ($appState = "active") then (
      mbr:disable-webapp(
        page:BasexHomePath(), 
        $appIdentifier
      )
    ) else
    if ($appState = "inactive") then (
      mbr:enable-webapp(
        page:BasexHomePath(), 
        $appIdentifier
      )
    ) 
    else (mbx:result(""))
  )

  return web:redirect("manage")
};


(:
    This function generates the "export" page.
    
    If the string is specified in $appName is not empty, 
    the component will attempt to export the application. 
    
    Otherwise, the export landing page 
    will be returned.
:)
declare
%rest:path("/manage-export")
%rest:form-param("appName", "{$appName}", "")
%rest:form-param("appAuthor", "{$appAuthor}", "-")
%rest:form-param("appEntryUrl", "{$appEntryUrl}", "/")
%rest:form-param("appDatabases", "{$appDatabases}")
%rest:form-param("appPackages", "{$appPackages}")
%output:method("xhtml")
%output:doctype-public("-//W3C//DTD XHTML 1.0 Transitional//EN")
%output:doctype-system("http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd")
function page:manage-export(
  $appName as xs:string, 
  $appAuthor as xs:string, 
  $appEntryUrl as xs:string, 
  $appDatabases as xs:string*, 
  $appPackages as xs:string*
) as element(Q{http://www.w3.org/1999/xhtml}html)
{
  if (string-length($appName) = 0)
  then mfe:export-landing(page:BasexHomePath())
  else (
   mfe:export-application(
      page:BasexHomePath(),
      $appName,
      $appAuthor,
      $appEntryUrl,
      $appDatabases,
      $appPackages
    )
  )
};

(:
    This function generates the "remove applications" page.

    If application identifiers are specified in $appIds, the component will
    attempt to remove them from the system.
:)
declare
%rest:path("/manage-remove")
%rest:query-param("appIds", "{$appIds}")
%output:method("xhtml")
%output:doctype-public("-//W3C//DTD XHTML 1.0 Transitional//EN")
%output:doctype-system("http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd")
function page:remove($appIds as xs:string*) 
as element(Q{http://www.w3.org/1999/xhtml}html) {
  if (empty($appIds)) then 
    mfr:installed-apps(page:BasexHomePath())
  else 
    mfr:remove-apps(
      page:BasexHomePath(), 
      $appIds
    )
};

(:
    This function generates the "imports" page.

    If a file is specified in $appFile, the component will
    attempt to import it into the system and return results.
    Otherwise, the import landing page will be returned.
:)
declare
%rest:path("/manage-import")
%rest:form-param("appFile", "{$appFile}")
%output:method("xhtml")
%output:doctype-public("-//W3C//DTD XHTML 1.0 Transitional//EN")
%output:doctype-system("http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd")
function page:manage-import($appFile)
as element(Q{http://www.w3.org/1999/xhtml}html) {
  if (empty($appFile)) then 
    mfi:import-landing() 
  else
    mfi:import-webapp(
      page:BasexHomePath(),
      $appFile
    )
};

(:~ 
    Returns the path of the BaseX home directory which is assumed to be
    located inside the BasexHomePath XML element, written in the 
    "landing-settings.xml" file.
    
    If this is not the case an exception will be thrown.
:)
declare
function page:BasexHomePath() 
as xs:string {
  (: We assume that landing-settings.xml is located inside the same
     directory as this file. :)
  let $path := mbf:append-to-path(
    file:base-dir(), 
    "landing-settings.xml")
  
  let $BasexHomePath := xs:string(fetch:xml($path)//BasexHomePath)

  (: Transform path to path used by operating system :)
  return file:path-to-native($BasexHomePath)
};

(:
    Retrieves static files to be displayed by the 
    RestXQ-annotated functions.

    Code taken and modified from BaseX. See 
    /manage/static/style.css for license.
:)
declare
%rest:path("manage/static/{$file=.+}")
function page:file($file as xs:string) 
as item()+ {
  let $path := mbs:manage-dir-path(page:BasexHomePath()) || '/static/' || $file
  return (
    web:response-header(
      map { 'media-type': web:content-type($path) }, 
      map{'Cache-Control': ''}
    ),
    file:read-binary($path)
  )
};
