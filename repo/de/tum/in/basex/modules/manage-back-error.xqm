module namespace mberr = 'http://in.tum.de/basex/modules/manage-back-error';

(:
    Returnes true if one or more Result element passed in $results
    returned false.
:)
declare
function mberr:has-error($results as element()) 
as xs:boolean {
  let $errors := (
    (: Multiple Results elements. Iterate
       and return only the ones that are errors. :)
    if (count($results//Result) > 0) then (
      for $r in $results//Result 
      where xs:boolean($r//Success) = fn:false()
      return fn:false()
    ) 

    else if (xs:string($results/@count) = "0") then ()
    
    (: Only one Result element, if it's not an error
       return empty sequence :)
    else if (xs:boolean($results/Success)) then ()
    (: Only one Result element which is an error 
       so return sequence with one false element :)
    else (true())
  )
  return if (fn:count($errors) > 0) then fn:true() else fn:false()
};

(:
  Returns a sequence of results
  that are located inside the $xml file.
:)
declare 
function mberr:get-result($xml as element())
as element()*
{
  (: If $xml is of type <Results /> then 
     $results should contain at least one
     element. :)
  let $results := $xml//Result
  return (
    if (count($results) > 0) then $results else 
    if (xs:string($xml/@count) = "0") then () else $xml
  )
};