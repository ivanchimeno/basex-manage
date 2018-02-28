module namespace mfr = 'http://in.tum.de/basex/modules/manage-front-html-remove';

import module namespace mbs = 'http://in.tum.de/basex/modules/manage-back-settings';
import module namespace mberr = 'http://in.tum.de/basex/modules/manage-back-error';
import module namespace mbi = 'http://in.tum.de/basex/modules/manage-back-import';
import module namespace mbx = 'http://in.tum.de/basex/modules/manage-back-xml';

import module namespace mfh = 'http://in.tum.de/basex/modules/manage-front-html';


(:
    Generates an HTML table containing a listing if all web applications 
    currently installed on the system and offers the user the possibility 
    to select which apps should be deleted. 

    Selected application to be deleted will be sent to the /manage-remove 
    URL via a POST request. 
:)
declare
function mfr:installed-apps($BaseXHomePath as xs:string)
as element(Q{http://www.w3.org/1999/xhtml}html) {
    let $listing := mbs:get-webapp-listing-contents($BaseXHomePath)
    return mfh:html("Remove",
        if (mberr:has-error($listing)) then 
            mfh:gen-error-table(
                $listing, 
                "An error has occured while reading webapp-listing.xml:")
        else (
            <div>
                <p>Select the applications you would like to remove from this system:</p>
                <form action="manage-remove" method="GET" enctype="multipart/form-data">
                <table>
                    <tr>
                        <th>Application Name</th>
                        <th>Author</th>
                        <th>Remove</th>
                    </tr>
                    {
                        for $x in $listing//WebAppSettings 
                        return (
                            <tr>
                            <td>{$x/AppName}</td>
                            <td>{$x/Author}</td>
                            <td>
                                <input type="checkbox" name="appIds" 
                                    value="{xs:string($x/@appIdentifier)}" />
                            </td>
                            </tr>
                        )
                        }
                    </table>
                    <br/>
                    <input type="submit" value="Delete Selection"/>
                </form>
            </div>
        )
    )
};

(:
    Attempts to remove all applications with their identifiers
    specified in $appIds.
    
     Generates HTML as a response.
:)
declare
function mfr:remove-apps($BaseXHomePath as xs:string, $appIds as xs:string*) 
as element(Q{http://www.w3.org/1999/xhtml}html) {
    let $remove := (
        for $aId in $appIds 
        return mberr:get-result(
            mbi:remove-webapp(
                $BaseXHomePath, 
                $aId
            )
        )
    )

    return mfh:html("Remove",
        if (mberr:has-error(mbx:results($remove))) then 
            mfh:gen-error-table(
                $remove, 
                "Something went wrong while deleting web applications:")
        else (
            <div>
                <p>The selected web applications have been successfully removed from this BaseX instance. </p>
                <p>You can go back to the landing screen by <a href="manage">clicking here</a>.</p>
            </div>
        )
    )
};
