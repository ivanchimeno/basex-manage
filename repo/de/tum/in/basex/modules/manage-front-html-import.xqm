module namespace m = 'http://in.tum.de/basex/modules/manage-front-html-import';

import module namespace map = 'http://www.w3.org/2005/xpath-functions/map';

import module namespace mberr = 'http://in.tum.de/basex/modules/manage-back-error';
import module namespace mbi = 'http://in.tum.de/basex/modules/manage-back-import';
import module namespace mfh = 'http://in.tum.de/basex/modules/manage-front-html';


(:
    Returns an HTML page containing the homepage of 
    the imports section of the component.
:)
declare
function m:import-landing()
as element(Q{http://www.w3.org/1999/xhtml}html) {
    mfh:html("Import",
        <div>
            <br/>
            <h2>Import a BaseX Web Application</h2>
            <p><a href='manage-import'>Importing</a> a web application via this tool will allow you to run your project onto this BaseX instance. After the import is complete, the application status will be automatically set to <code>inactive</code>.</p>
            <p>If you would like to run the application, press the play button located on the <a href='manage'>Applications</a> page under the project listings.</p>
            <br/>
            <h3>Import Settings</h3>
            <p>Please select the web application you would like to import. The web application has to be exported via this tool and ends with the <code>.manage</code> file extension.</p>
            <form action="manage-import" method="POST" enctype="multipart/form-data">
                <input type="file" name="appFile" accept=".manage"></input>
                <input type="submit" value="Import Application"></input>
            </form>
            <br/>
        </div>
    )
};

(:
    Imports the contents of the file specified in $appFile
    and returns an HTML page containing the results returned
    by the import.
:)
declare
function m:import-webapp($BaseXHomePath as xs:string, $appFile) 
as element(Q{http://www.w3.org/1999/xhtml}html) {
    for $fileName in map:keys($appFile)
        let $fileContent := $appFile($fileName)
        let $importResult := mbi:import-archive(
            $BaseXHomePath, 
            $fileName, 
            $fileContent, 
            false()
        )
    return mfh:html("Import",
        if (not(mberr:has-error($importResult))) then (
            <div>
                <h3>Import Successful!</h3>
                <p>Your web application has been successfully imported. You can run it or 
                manage other web applications by accessing the <a href='manage'>manage</a> page.</p>
            </div>
        ) else (
            <div>
                <h3>Import Failed :(</h3>
                {mfh:gen-error-table($importResult, "An error has occured while importing the application:")}
                <p>You can go back to the <a href='manage-import'>import</a> page and try again.</p>
            </div>
        )
    )
};