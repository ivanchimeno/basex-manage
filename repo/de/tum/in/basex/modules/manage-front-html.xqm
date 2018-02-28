module namespace m = 'http://in.tum.de/basex/modules/manage-front-html';

import module namespace mberr = 'http://in.tum.de/basex/modules/manage-back-error'; 

(:
    Generates a HTML navigation menu. Menu item specified
    in $current will be bolded out.

    Code taken and modified from BaseX. See 
    /manage/static/style.css for license.
:)
declare
function m:menu($current as xs:string) {
  let $menu := (
    for $m in ("Applications", "Import", "Export", "Remove") 
      let $link := <a href="{lower-case("manage"||(if ($m="Applications") then "" else "-"||$m))}">{$m}</a>
    return if ($m=$current) then <b>{$link}</b> else $link
  )
  return (head($menu), tail($menu) ! (' | ', .))
};

(:
    Generates the outer HTML code and inserts HTML content specified
    in $content. $current specified the currently 
    selected menu item.
:)
declare
function m:html($current as xs:string, $content) {
  <html xmlns="http://www.w3.org/1999/xhtml">
    <head>
      <title>BaseX Mangement Component</title>
      <link rel="stylesheet" type="text/css" href="manage/static/style.css"/>
      <link rel="stylesheet" type="text/css" href="manage/static/deploy-landing-styles.css"/>
    </head>
    <body>
      <div><p>{m:menu($current)}</p></div>
      <hr/>
      {$content}
    </body>
  </html>
};

(:~ Generates an HTML table containing information about the error
    stored inside $errXml.

    Must be xml generated via dxt:error() 
:)
declare 
function m:gen-error-table($errXml as element(), $errTitle as xs:string) {
  <p>
  <p>{$errTitle}</p>
  <table>
    <tr>
      <th>Error Code</th>
      <th>Description</th>
      <th>Module</th>
    </tr>
    {
      if (mberr:has-error($errXml))
      then (
        for $r in $errXml//Result
        where xs:boolean($r//Success) = fn:false()
        return (
          <tr>
            <td>{$r//Code}</td>
            <td>{$r//Description}</td>
            <td>{$r//Module}</td>
          </tr>
        )
      )
      else (
        <tr>
          <td>{$errXml//Code}</td>
          <td>{$errXml//Description}</td>
          <td>{$errXml//Module}</td>
        </tr>
      )
    }
  </table>
  </p>
};
