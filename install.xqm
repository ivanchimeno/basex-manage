import module namespace file = 'http://expath.org/ns/file';
import module namespace utils = 'http://in.tum.de/basex/modules/utils' at 'utils.xqm';
import module namespace fetch = 'http://basex.org/modules/fetch';

(:
    Path to target BaseX directory should be inserted
    here.
:)
let $BasexHomePath := "C:\Program Files (x86)\BaseX\"

(:
    We assume that the web application component files
    are located inside the same directory as this install
    script.

    If this is not the case, edit it to point to the current
    directory.
:)
let $InstallPath := file:base-dir()

(:  Transform path to native representation of the
    operating system and append .basex to it because
    that's where the file is usually located. :)
let $BasexConfFile := file:path-to-native($BasexHomePath) || ".basex"


return try {
    (: Contains useful messages about the installation process. :)
    let $msg := ()

    (:
        Step 1: Attempt to read the .basex configuration file
                and append MIXUPDATES = true to it.
    :)
    let $hasEntry := filter(
        file:read-text-lines($BasexConfFile),
        contains(?, "MIXUPDATES")
    )    
    
    let $msg := insert-before($msg, count($msg) + 1,
        (: Append option since it doesn't exist :)
        if (not($hasEntry)) then (
            file:append-text-lines(
                $BasexConfFile,
                "MIXUPDATES = true"
            ),
            "Added MIXUPDATES=true to .basex."
        )
        else "Skipped adding 'MIXUPDATES=true' to .basex because it already exists."
    )

    (:
        Step 2: Copy front-end and back-end XQuery modules which are 
                located inside the repo/ sub-directory to the repository
                directory of the target BaseX installation.

                The REPOPATH option inside the .basex file will be read
                and used as the target directory.
    :)
    let $repoPath := file:path-to-native(
        utils:value-of-key(
            $BasexConfFile, 
            "REPOPATH", 
            "="
        )
    )

    let $msg := insert-before($msg, count($msg) + 1,
        utils:copy(
            $InstallPath || "repo" || file:dir-separator() || "de",
            $repoPath || "de"
        )
    )

    (:
        Step 3: Copy the manage directory to the web application
                directory on the target BaseX installation.

                Web application directory path is defined via
                the WEBPATH option inside the configuration file.
    :)
    let $webPath := file:path-to-native(
        utils:value-of-key(
            $BasexConfFile,
            "WEBPATH",
            "="
        )
    )
    
    let $msg := insert-before($msg, count($msg) + 1,
        utils:copy(
            $InstallPath || "manage",
            $webPath || "manage"
        )
    )

    (:
        Step 4: Update the landing-settings.xml with
        the path specified in $BasexHomePath
    :)
    let $path := file:path-to-native($webPath || "manage" || file:dir-separator() || "landing-settings.xml")
    let $msg := insert-before($msg, count($msg)+1, 
        utils:write-xml($path,
            copy $xx := fetch:xml($path)
            modify(
                replace value of node $xx//BasexHomePath with $BasexHomePath
            )
            return $xx
        )
    )

    (:
        Step 5: Create a restxq directory inside the web application
                directory and move all xquery files into it.
    :)
    let $msg := insert-before($msg, count($msg) + 1,
        (
            let $dstPath := $webPath || "restxq"
            return if (file:exists($dstPath))
            then "Skipped creating directory because " || $dstPath || " already exists." 
            else (file:create-dir($dstPath), "Created directory at " || $dstPath)
        )
    )

    let $msg :=insert-before ($msg, count($msg) + 1,
        (
            let $dstDir := $webPath || "restxq" || file:dir-separator()
            
            let $files := file:list(
                $webPath,
                false(),
                "*.xq, *.xqm, *.xqy, *.xql, *.xqu, *.xquery"
            )

            for $f in $files
                let $f := $webPath || $f
                let $dstDir := $dstDir || file:name($f)
            return (
                file:copy($f, $dstDir), 
                file:delete($f), 
                "Moved " || file:name($f) || " to " || $dstDir
            )
        )
    )
        
    return ($msg, "&#10; Installation complete. Please restart the server for changes to take affect.")
} catch * {
    "An error has occured. &#10;&#10; Error Description: " || $err:description 
    || "&#10; Error Code: " || $err:code
    || "&#10; Module: " || $err:module
    || "&#10; Line : " || $err:line-number || " Column: " || $err:column-number
    || "&#10; Trace : " || $err:additional
}

