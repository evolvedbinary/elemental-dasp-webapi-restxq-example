xquery version "3.1";

(:~
 : A very simple example XQuery Library Module implemented
 : in XQuery.
 :)
module namespace srv = "http://ns.evolvedbinary.com/dasp/service";

import module namespace hsc = "https://tools.ietf.org/html/rfc2616#section-10" at "http-status-codes.xqm";
import module namespace sm = "http://exist-db.org/xquery/securitymanager";
import module namespace util = "http://exist-db.org/xquery/util";
import module namespace xmldb = "http://exist-db.org/xquery/xmldb";

declare namespace dasp = "http://ns.declarative.amsterdam/dasp";
declare namespace http = "http://expath.org/ns/http-client";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace rest = "http://exquery.org/ns/restxq";
declare namespace xupdate = "http://www.xmldb.org/xupdate";


declare %private variable $srv:documents-collection-path := "/db/dasp-documents";

declare
    %rest:PUT("{$content}")
    %rest:path("/document")
    %rest:header-param("Content-Type", "{$content-type}")
    %rest:consumes("application/xml", "application/json")
    %rest:produces("application/xml")
    %output:method("xml")
function srv:create-document-xml-response($content, $content-type) {
  srv:create-document($content, $content-type)
};

declare
    %rest:PUT("{$content}")
    %rest:path("/document")
    %rest:header-param("Content-Type", "{$content-type}")
    %rest:consumes("application/xml", "application/json")
    %rest:produces("application/json")
    %output:method("json")
function srv:create-document-json-response($content, $content-type) {
  srv:create-document($content, $content-type)
};

declare
    %private
function srv:create-document($content, $content-type) {
  let $random-uuid := util:uuid()
  let $ext :=
        if ($content-type = "application/json")
        then
          ".json"
        else
          ".xml"
  let $document-name := $random-uuid || $ext

  let $document-uri := xmldb:store($srv:documents-collection-path, $document-name, $content, $content-type)

  let $domain-document := srv:to-domain-document($document-uri)
  return
    <rest:response>
      <http:response status="{$hsc:created}">
        <http:header name="Location" value="{rest:uri() || "/" || $document-name}"/>
        <http:header name="Last-Modified" value="{srv:to-http-date(xs:dateTime($domain-document/dasp:document/@last-modified))}"/>
      </http:response>
    </rest:response>
};

declare
    %rest:GET
    %rest:path("/document")
    %rest:header-param("If-Modified-Since", "{$if-modified-since}")
    %rest:produces("application/xml")
    %output:method("xml")
function srv:list-documents-xml($if-modified-since) {
  srv:list-documents($if-modified-since)
};

declare
    %rest:GET
    %rest:path("/document")
    %rest:header-param("If-Modified-Since", "{$if-modified-since}")
    %rest:produces("application/json")
    %output:method("json")
function srv:list-documents-json($if-modified-since) {
  srv:list-documents($if-modified-since)
};

declare
    %private
function srv:list-documents($if-modified-since) {
  let $document-names := xmldb:get-child-resources($srv:documents-collection-path)
  let $domain-documents := $document-names ! srv:to-domain-document($srv:documents-collection-path || "/" || .)
  let $last-modified := srv:get-last-modified($domain-documents)
  let $not-modified := srv:not-modified($if-modified-since, $last-modified)
  return

    (: check if the documents have been modified since the If-Modified-Since header :)
    if ($not-modified)
    then
      $not-modified

    else
      (
        <rest:response>
          <http:response status="{$hsc:ok}">
            <http:header name="Last-Modified" value="{srv:to-http-date($last-modified)}"/>
          </http:response>
        </rest:response>,
        srv:to-domain-documents($domain-documents)
      )
};

declare
    %rest:GET
    %rest:path("/document/{$document-id}")
    %rest:header-param("If-Modified-Since", "{$if-modified-since}")
    %rest:produces("application/xml")
    %output:method("xml")
function srv:get-document-xml($document-id, $if-modified-since) {
  srv:get-document($document-id, $if-modified-since)
};

declare
    %rest:GET
    %rest:path("/document/{$document-id}")
    %rest:header-param("If-Modified-Since", "{$if-modified-since}")
    %rest:produces("application/json")
    %output:method("json")
function srv:get-document-json($document-id, $if-modified-since) {
  srv:get-document($document-id, $if-modified-since)
};

declare
    %private
function srv:get-document($document-id, $if-modified-since) {
  let $document-not-found := srv:document-not-found($document-id)
  return
    if ($document-not-found)
    then
      $document-not-found
    else
      let $last-modified := xmldb:last-modified($srv:documents-collection-path, $document-id)
      let $not-modified := srv:not-modified($if-modified-since, $last-modified)
      return
        if ($not-modified)
        then
          $not-modified

        else
          (
            <rest:response>
              <http:response status="{$hsc:ok}">
                <http:header name="Last-Modified" value="{srv:to-http-date($last-modified)}"/>
              </http:response>
            </rest:response>,
            let $document-uri := $srv:documents-collection-path || "/" || $document-id
            return
              if (util:is-binary-doc($document-uri))
              then
                util:binary-doc($document-uri)
              else
                fn:doc($document-uri)
          )
};

declare
    %rest:PUT("{$content}")
    %rest:path("/document/{$document-id}")
    %rest:header-param("Content-Type", "{$content-type}")
    %rest:consumes("application/xml", "application/json")
function srv:replace-document($content, $document-id, $content-type) {
  let $document-not-found := srv:document-not-found($document-id)
  return
    if ($document-not-found)
    then
      $document-not-found

    else
      let $document-uri := xmldb:store($srv:documents-collection-path, $document-id, $content, $content-type)
      let $last-modified := xmldb:last-modified($srv:documents-collection-path, $document-id)
      return
        <rest:response>
          <http:response status="{$hsc:no-content}">
            <http:header name="Last-Modified" value="{srv:to-http-date($last-modified)}"/>
          </http:response>
        </rest:response>
};

declare
    %rest:DELETE
    %rest:path("/document/{$document-id}")
function srv:delete-document($document-id) {
  let $document-not-found := srv:document-not-found($document-id)
  return
    if ($document-not-found)
    then
      $document-not-found

    else
      let $_ := xmldb:remove($srv:documents-collection-path, $document-id)
      return
        <rest:response>
          <http:response status="{$hsc:no-content}"/>
        </rest:response>
};

declare
    %rest:PATCH("{$content}")
    %rest:path("/document/{$document-id}")
    %rest:consumes("application/xml")
function srv:update-document($content, $document-id) {
  let $document-not-found := srv:document-not-found($document-id)
  return
    if ($document-not-found)
    then
      $document-not-found

    else if (fn:not($content instance of document-node(element(xupdate:modifications))))
    then
     (
       <rest:response>
          <http:response status="{$hsc:bad-request}"/>
       </rest:response>,
       srv:error($hsc:not-found, "Content was not an XUpdate modifications element")
     )

     else
       let $modifications-processed := xmldb:update($srv:documents-collection-path, $document-id, $content/xupdate:modifications)
       let $last-modified := xmldb:last-modified($srv:documents-collection-path, $document-id)
       return
         <rest:response>
           <http:response status="{$hsc:no-content}">
             <http:header name="Last-Modified" value="{srv:to-http-date($last-modified)}"/>
             <http:header name="X-XUpdate-Modifications" value="{$modifications-processed}"/>
           </http:response>
         </rest:response>
};

declare
    %private
function srv:to-domain-document($document-uri as xs:string) as document-node(element(dasp:document)) {
  let $id := fn:replace($document-uri, ".+/(.+)$", "$1")
  let $created := xmldb:created($srv:documents-collection-path, $id)
  let $last-modified := xmldb:last-modified($srv:documents-collection-path, $id)
  let $permissions := sm:get-permissions(xs:anyURI($document-uri))
  return
    document {
      element dasp:document {
        attribute id { $id },
        attribute created { $created },
        attribute last-modified {$last-modified},
        $permissions/sm:permission/@owner,
        $permissions/sm:permission/@group,
        attribute permissions { $permissions/sm:permission/string(@mode) }
      }
    }
};

declare
    %private
function srv:to-domain-documents($domain-documents as document-node(element(dasp:document))*) as document-node(element(dasp:documents)) {
  document {
    element dasp:documents {
      $domain-documents
    }
  }
};

declare
    %private
function srv:get-last-modified($domain-documents as document-node(element(dasp:document))*) as xs:dateTime? {
  fn:max($domain-documents/dasp:document/@last-modified ! xs:dateTime(.))
};

declare
    %private
function srv:to-http-date($date as xs:dateTime) as xs:string {
  fn:format-dateTime(
      fn:adjust-dateTime-to-timezone($date, xs:dayTimeDuration('PT0H')),
      "[FNn,*-3], [D01] [MNn,*-3] [Y] [H01]:[m01]:[s01] GMT",
      "en",
      (),
      ()
  )
};

declare
    %private
function srv:from-http-date($date as xs:string) as xs:dateTime {
  let $dt-components := fn:analyze-string($date, "[A-Za-z]{3},\s([0-9]{2})\s([A-Za-z]{3})\s([0-9]{4})\s([0-9]{2}:[0-9]{2}:[0-9]{2})\s([A-Z\-+0-9:]+)")
  let $day := $dt-components/fn:match/fn:group[@nr eq "1"]
  let $month-abbrev := $dt-components/fn:match/fn:group[@nr eq "2"]
  let $month := format-number(srv:month-num($month-abbrev), "00")
  let $year := $dt-components/fn:match/fn:group[@nr eq "3"]
  let $time := $dt-components/fn:match/fn:group[@nr eq "4"]
  let $timezone-abbrev := $dt-components/fn:match/fn:group[@nr eq "5"]
  return
    xs:dateTime($year || "-" || $month || "-" || $day || "T" || $time || "Z")
};

declare
    %private
function srv:month-num($month-abbrev as xs:string) as xs:integer {
  fn:index-of(("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"), $month-abbrev)
};

declare
    %private
function srv:error($code, $message as xs:string) as document-node(element(dasp:error)) {
  document {
    element dasp:error {
      element dasp:code { $code },
      element dasp:message { $message }
    }
  }
};

declare
    %private
function srv:document-not-found($document-id as xs:string) as node()* {
  let $document-uri := $srv:documents-collection-path || "/" || $document-id
  return
    if (fn:not(fn:doc-available($document-uri) or util:binary-doc-available($document-uri)))
    then
      (
        <rest:response>
          <http:response status="{$hsc:not-found}"/>
        </rest:response>,
        srv:error($hsc:not-found, "No such document: " || $document-id)
      )
    else
      ()
};

declare
    %private
function srv:not-modified($if-modified-since, $last-modified as xs:dateTime) as element(rest:response)? {
  if (exists($if-modified-since) and srv:from-http-date($if-modified-since) gt $last-modified)
  then
    <rest:response>
      <http:response status="{$hsc:not-modified}">
        <http:header name="Last-Modified" value="{srv:to-http-date($last-modified)}"/>
      </http:response>
    </rest:response>
  else
    ()
};
