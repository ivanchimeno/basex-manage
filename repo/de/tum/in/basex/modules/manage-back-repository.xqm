module namespace mbr = 'http://in.tum.de/basex/modules/manage-back-repository';

import module namespace file = 'http://expath.org/ns/file';

import module namespace mbx = 'http://in.tum.de/basex/modules/manage-back-xml';
import module namespace mberr = 'http://in.tum.de/basex/modules/manage-back-error';
import module namespace mbf = 'http://in.tum.de/basex/modules/manage-back-file';


(:  Returns a list of installed repository packages
    without including packages from the manage component
    or hidden files.

    The list has the following format:
        <Packages count="n">
            <Package path="RELATIVE_PACKAGE_PATH">PACKAGE_NAME-1</Package>
            ....
            <Package path="RELATIVE_PACKAGE_PATH">PACKAGE_NAME-n</Package>
        </Packages>

    Returns a single result.
:)
declare
function mbr:installed-repos($repoPath as xs:string)
as element() {
    try {
        let $repoPath := file:path-to-native($repoPath)
        let $repoList := mbf:list($repoPath, fn:true(), "")
        return (
            if (mberr:has-error($repoList)) then $repoList
            else (
                let $pkgs := (
                    for $r in $repoList//file
                        let $r := $r//text()
                        let $name := file:name($r)
                        let $path := file:resolve-path($r, $repoPath)
                    where (
                        file:is-file($path) and
                        not(starts-with($name, "manage-")) and
                        substring($name,1,1) != '.'
                    )
                    return <Package path="{$r}">{$name}</Package>
                )
                return mbx:result(<Packages count="{fn:count($pkgs)}">{$pkgs}</Packages>)
            )
        ) 
    } catch * {
        mbx:error($err:code, $err:description, $err:module)
    }
};

(:
    Removes all external XQuery modules from the repository
    system specified in $repoPath.

    Returns multiple results.
:)
declare
function mbr:remove-repos($repoPath as xs:string) 
as element() {
    let $rList := mbr:installed-repos($repoPath)
    return mbx:results(
        if (mberr:has-error($rList)) then $rList
        else (
            (:  Sequence of deletion results. We iterate
                over every external XQuery module and remove
                it's parent directory. :)
            let $r := (
                for $pkg in $rList//Package
                    let $path := file:parent(
                        mbf:append-to-path(
                            $repoPath,
                            xs:string($pkg/@path)
                        )
                    )
                return mbf:delete-file-dir($path)
            )
            return $r
        )
    )
};

(:
    Returns true/false if any other external XQuery packages are
    installed into the BaseX instance.

    Returns a single result.
:)
declare
function mbr:has-installed-repos($repoPath as xs:string)
as element() {
    let $l := mbr:installed-repos($repoPath)
    return (
        if (mberr:has-error($l)) then $l
        else mbx:result(count($l//Package) > 0)
    )
};