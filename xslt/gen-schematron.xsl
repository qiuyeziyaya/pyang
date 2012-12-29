<?xml version="1.0" encoding="utf-8"?>

<!-- Program name: gen-schematron.xsl

Copyright © 2012 by Ladislav Lhotka, CZ.NIC <lhotka@nic.cz>

Creates Schematron schema from the hybrid DSDL schema (see RFC 6110).

Permission to use, copy, modify, and/or distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
-->

<!-- Edit the "annots" entity to select the annotations to take into
     account. -->
<!DOCTYPE stylesheet [
<!ENTITY annots "nma:must|nma:instance-identifier|nma:unique|@nma:key|
@nma:max-elements|@nma:min-elements|@nma:when|@nma:leafref|@nma:leaf-list|
@nma:mandatory">
]>

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:rng="http://relaxng.org/ns/structure/1.0"
                xmlns:sch="http://purl.oclc.org/dsdl/schematron"
                xmlns:nma="urn:ietf:params:xml:ns:netmod:dsdl-annotations:1"
                version="1.0">

  <xsl:output method="xml" encoding="utf-8"/>
  <xsl:strip-space elements="*"/>

  <xsl:include href="gen-common.xsl"/>

  <!-- Fast access to named pattern definitions by their name -->
  <xsl:key name="refdef" match="//rng:define" use="@name"/>

  <xsl:template name="assert-element">
    <xsl:param name="test"/>
    <xsl:param name="message"/>
    <xsl:element name="sch:assert">
      <xsl:attribute name="test">
        <xsl:value-of select="$test"/>
      </xsl:attribute>
      <xsl:value-of select="$message"/>
    </xsl:element>
  </xsl:template>

  <xsl:template name="report-element">
    <xsl:param name="test"/>
    <xsl:param name="message"/>
    <xsl:element name="sch:report">
      <xsl:attribute name="test">
        <xsl:value-of select="$test"/>
      </xsl:attribute>
      <xsl:value-of select="$message"/>
    </xsl:element>
  </xsl:template>

  <!-- Insert namespace declaration based on the target document type -->
  <xsl:template name="nc-namespace">
    <xsl:choose>
      <xsl:when test="$target='config' or $target='get-reply' or
                      $target='get-config-reply' or $target='data'
                      or $target='rpc' or $target='rpc-reply'">
          <sch:ns uri="{$nc-uri}" prefix="nc"/>
      </xsl:when>
      <xsl:when test="$target='notification'">
          <sch:ns uri="{$en-uri}" prefix="en"/>
      </xsl:when>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="qname">
    <xsl:param name="name" select="@name"/>
    <xsl:if test="not(contains($name,':'))">$pref:</xsl:if>
    <xsl:value-of select="$name"/>
  </xsl:template>

  <xsl:template name="uproot">
    <xsl:param name="path" select="."/>
    <xsl:choose>
      <xsl:when test="starts-with($path,'$root')">
	<xsl:value-of select="concat($netconf-part,'/',
			      substring-after($path,'/'))"/>
      </xsl:when>
      <xsl:otherwise>
	<xsl:value-of select="$path"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="yam-namespaces">
    <!-- Declare all YANG module namespaces by excluding others
         declared in the input hybrid schema -->
    <xsl:for-each
        select="namespace::*[not(name()='xml' or .=$rng-uri or
                .=$dtdc-uri or .=$dc-uri or .=$nma-uri)]">
      <sch:ns uri="{.}" prefix="{name()}"/>
    </xsl:for-each>
  </xsl:template>

  <xsl:template name="uniq-expr-comp">
    <xsl:param name="key"/>
    <xsl:variable name="qkey">
      <xsl:call-template name="qname">
        <xsl:with-param name="name" select="$key"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:value-of select="concat($qkey,'=current()/',$qkey)"/>
  </xsl:template>

  <xsl:template name="check-dup-expr">
    <xsl:param name="nodelist"/>
    <xsl:choose>
      <xsl:when test="contains($nodelist,' ')">
        <xsl:call-template name="uniq-expr-comp">
          <xsl:with-param name="key"
                          select="substring-before($nodelist, ' ')"/>
        </xsl:call-template>
        <xsl:text> and </xsl:text>
        <xsl:call-template name="check-dup-expr">
          <xsl:with-param name="nodelist"
                          select="substring-after($nodelist,' ')"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>  <!-- just one node -->
        <xsl:call-template name="uniq-expr-comp">
          <xsl:with-param name="key"
                          select="$nodelist"/>
        </xsl:call-template>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="top-rule">
    <xsl:param name="ctx">$start</xsl:param>
    <xsl:variable
	name="todo"
	select="(descendant::rng:choice[@nma:when or @nma:mandatory]
		|(descendant::group|descendant::interleave)[@nma:when])
		[not(ancestor::rng:element)]"/>
    <xsl:if test="count($todo) &gt; 0">
      <xsl:element name="sch:rule">
	<xsl:attribute name="context">
	  <xsl:value-of select="$ctx"/>
	</xsl:attribute>
	<xsl:apply-templates select="$todo">
	  <xsl:with-param name="prefix">$pref</xsl:with-param>
	</xsl:apply-templates>
      </xsl:element>
    </xsl:if>
  </xsl:template>

  <xsl:template name="element-count">
    <xsl:param name="ord">&lt;</xsl:param>
    <xsl:variable name="qn">
      <xsl:call-template name="qname">
	<xsl:with-param name="name" select="../@name"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:call-template name="assert-element">
      <xsl:with-param
	  name="test"
	  select="concat('preceding-sibling::',$qn,
		  ' or count(../',$qn,')',$ord,'=',.)"/>
      <xsl:with-param name="message">
	<xsl:text>Number of </xsl:text>
	<xsl:if test="../@nma:leaf-list">leaf-</xsl:if>
	<xsl:text>list entries must be at </xsl:text>
	<xsl:choose>
	  <xsl:when test="$ord='&lt;'">most </xsl:when>
	  <xsl:otherwise>least </xsl:otherwise>
	</xsl:choose>
	<xsl:value-of select="."/>
      </xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <xsl:template match="/">
    <xsl:call-template name="check-input-pars"/>
    <xsl:element name="sch:schema">
      <xsl:attribute name="queryBinding">exslt</xsl:attribute>
      <xsl:element name="sch:ns">
	<xsl:attribute name="uri">
	  <xsl:text>http://exslt.org/dynamic</xsl:text>
	</xsl:attribute>
	<xsl:attribute name="prefix">dyn</xsl:attribute>
      </xsl:element>
      <xsl:apply-templates select="rng:grammar"/>
    </xsl:element>
  </xsl:template>

  <xsl:template match="/rng:grammar">
    <xsl:call-template name="yam-namespaces"/>
    <xsl:call-template name="nc-namespace"/>
    <!-- The global 'root' variable contains the target-dependent
         prefix of every absolute path. -->
    <xsl:element name="sch:let">
      <xsl:attribute name="name">root</xsl:attribute>
      <xsl:attribute name="value">
	<xsl:value-of select="$netconf-part"/>
      </xsl:attribute>
    </xsl:element>
    <xsl:apply-templates
        select="rng:define[descendant::rng:*[&annots;]]"/>
    <xsl:apply-templates select="descendant::rng:grammar"/>
  </xsl:template>

  <xsl:template match="rng:define">
    <xsl:element name="sch:pattern">
      <xsl:attribute name="abstract">true</xsl:attribute>
      <xsl:attribute name="id">
        <xsl:value-of select="@name"/>
      </xsl:attribute>
      <!-- handle descendant choices without intervening elements-->
      <xsl:call-template name="top-rule"/>
      <!-- handle all descendant elements-->
      <xsl:apply-templates select="descendant::rng:element"/>
    </xsl:element>
  </xsl:template>

  <xsl:template match="rng:grammar">
    <xsl:apply-templates
        select="rng:define[descendant::rng:*[&annots;]]"/>
    <xsl:choose>
      <xsl:when test="$target='data' or $target='config' or
                      $target='get-reply' or $target='get-config-reply'">
        <xsl:apply-templates select="descendant::nma:data"/>
      </xsl:when>
      <xsl:when test="$target='rpc'">
        <xsl:apply-templates select="descendant::nma:input"/>
      </xsl:when>
      <xsl:when test="$target='rpc-reply'">
        <xsl:apply-templates select="descendant::nma:output"/>
      </xsl:when>
      <xsl:when test="$target='notification'">
        <xsl:apply-templates select="descendant::nma:notification"/>
      </xsl:when>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="nma:data|nma:input|nma:output|nma:notification">
    <xsl:variable
        name="prefix"
        select="name(namespace::*[.=ancestor::rng:grammar[1]/@ns])"/>
    <xsl:element name="sch:pattern">
      <xsl:attribute name="id">
        <xsl:value-of select="ancestor::rng:grammar[1]/@nma:module"/>
      </xsl:attribute>
      <!-- The 'pref' variable in the Schematron schema contains the
	   module prefix for the current pattern. -->
      <xsl:call-template name="top-rule">
	<xsl:with-param name="ctx" select="$netconf-part"/>
      </xsl:call-template>
      <xsl:apply-templates select="descendant::rng:element">
	<xsl:with-param name="prefix" select="$prefix"/>
      </xsl:apply-templates>
    </xsl:element>
    <xsl:apply-templates
        mode="ref"
        select="rng:element|rng:optional|rng:choice|rng:group|rng:ref|
                rng:interleave|rng:zeroOrMore|rng:oneOrMore">
      <xsl:with-param name="prevpath" select="$netconf-part"/>
      <xsl:with-param name="prefix" select="$prefix"/>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template match="rng:element">
    <xsl:param name="prefix"/>
    <xsl:variable
	name="todo"
	select="&annots;|(descendant::rng:choice[@nma:when or @nma:mandatory]
		|(descendant::rng:interleave|descendant::rng:group)
		[@nma:when])[count(ancestor::rng:element[1]|current())=1]"/>
    <xsl:if test="count($todo) &gt; 0">
      <xsl:element name="sch:rule">
	<xsl:attribute name="context">
	  <xsl:choose>
	    <xsl:when test="ancestor::rng:define">$start</xsl:when>
	    <xsl:otherwise>
	      <xsl:value-of select="$netconf-part"/>
	    </xsl:otherwise>
	  </xsl:choose>
	  <xsl:for-each select="ancestor-or-self::rng:element">
	    <xsl:text>/</xsl:text>
	    <xsl:call-template name="qname"/>
	  </xsl:for-each>
	</xsl:attribute>
	<xsl:apply-templates select="$todo">
	  <xsl:with-param name="prefix" select="$prefix"/>
	</xsl:apply-templates>
      </xsl:element>
    </xsl:if>
  </xsl:template>

  <xsl:template match="rng:*">
    <xsl:param name="prefix"/>
    <xsl:apply-templates select="&annots;">
      <xsl:with-param name="prefix" select="$prefix"/>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template match="rng:choice/@nma:mandatory">
    <xsl:param name="prefix"/>
    <xsl:call-template name="assert-element">
      <xsl:with-param name="test">
	<xsl:apply-templates select=".." mode="lookup-subel">
	  <xsl:with-param name="prefix" select="$prefix"/>
	</xsl:apply-templates>
	<xsl:text>false()</xsl:text>
      </xsl:with-param>
      <xsl:with-param
	  name="message"
	  select="concat('Node(s) from one case of mandatory choice &quot;',
		  ../@nma:name,'&quot; must exist')"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template match="rng:choice/@nma:when|rng:group/@nma:when|
		       rng:interleave/@nma:when">
    <xsl:param name="prefix"/>
    <xsl:call-template name="report-element">
      <xsl:with-param name="test">
	<xsl:value-of select="concat('not(', ., ') and (')"/>
	<xsl:apply-templates select=".." mode="lookup-subel">
	  <xsl:with-param name="prefix" select="$prefix"/>
	</xsl:apply-templates>
	<xsl:text>false())</xsl:text>
      </xsl:with-param>
      <xsl:with-param
	  name="message"
	  select="concat('Found nodes that are valid only when &quot;',
		  .,'&quot;')"/>
    </xsl:call-template>
  </xsl:template>
  
  <xsl:template match="rng:element" mode="lookup-subel">
    <xsl:param name="prefix"/>
    <xsl:choose>
      <xsl:when test="contains(@name, ':')">
	<xsl:value-of select="@name"/>
      </xsl:when>
      <xsl:otherwise>
	<xsl:value-of select="concat($prefix, ':', @name)"/>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:text> or </xsl:text>
  </xsl:template>

  <xsl:template match="rng:ref" mode="lookup-subel">
    <xsl:param name="prefix"/>
    <xsl:apply-templates select="key('refdef', @name)"
			 mode="lookup-subel">
      <xsl:with-param name="prefix" select="$prefix"/>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template match="rng:*" mode="lookup-subel">
    <xsl:param name="prefix"/>
    <xsl:apply-templates
	mode="lookup-subel"
	select="rng:element|rng:optional|rng:choice|rng:group|rng:ref|
		rng:interleave|rng:zeroOrMore|rng:oneOrMore">
      <xsl:with-param name="prefix" select="$prefix"/>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template match="rng:ref[@name='__anyxml__']" mode="ref"/>

  <xsl:template match="rng:ref" mode="ref">
    <xsl:param name="prevpath"/>
    <xsl:param name="prefix"/>
    <xsl:choose>
      <xsl:when
	  test="key('refdef',@name)[descendant::rng:*[&annots;]]">
	<xsl:element name="sch:pattern">
	  <xsl:attribute name="id">
	    <xsl:value-of select="generate-id()"/>
	  </xsl:attribute>
	  <xsl:attribute name="is-a">
	    <xsl:value-of select="@name"/>
	  </xsl:attribute>
	  <xsl:element name="sch:param">
	    <xsl:attribute name="name">start</xsl:attribute>
	    <xsl:attribute name="value">
	      <xsl:value-of select="$prevpath"/>
	    </xsl:attribute>
	  </xsl:element>
	  <xsl:element name="sch:param">
	    <xsl:attribute name="name">pref</xsl:attribute>
	    <xsl:attribute name="value">
	      <xsl:value-of select="$prefix"/>
	    </xsl:attribute>
	  </xsl:element>
	</xsl:element>
      </xsl:when>
      <xsl:otherwise>
	<xsl:apply-templates select="key('refdef',@name)" mode="ref">
	  <xsl:with-param name="prevpath" select="$prevpath"/>
	  <xsl:with-param name="prefix" select="$prefix"/>
	</xsl:apply-templates>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="rng:element" mode="ref">
    <xsl:param name="prevpath"/>
    <xsl:param name="prefix"/>
    <xsl:apply-templates
        mode="ref"
        select="rng:element|rng:optional|rng:choice|rng:group|rng:ref|
                rng:interleave|rng:zeroOrMore|rng:oneOrMore">
      <xsl:with-param name="prevpath">
        <xsl:value-of select="concat($prevpath,'/')"/>
	<xsl:if test="not(contains(@name,':'))">
	  <xsl:value-of select="concat($prefix,':')"/>
	</xsl:if>
	<xsl:value-of select="@name"/>
      </xsl:with-param>
      <xsl:with-param name="prefix" select="$prefix"/>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template match="rng:*" mode="ref">
    <xsl:param name="prevpath"/>
    <xsl:param name="prefix"/>
    <xsl:apply-templates
        mode="ref"
        select="rng:element|rng:optional|rng:choice|rng:group|rng:ref|
                rng:interleave|rng:zeroOrMore|rng:oneOrMore">
      <xsl:with-param name="prevpath" select="$prevpath"/>
      <xsl:with-param name="prefix" select="$prefix"/>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template match="nma:must">
    <xsl:call-template name="assert-element">
      <xsl:with-param name="test" select="@assert"/>
      <xsl:with-param name="message">
	<xsl:choose>
	  <xsl:when test="nma:error-message">
	    <xsl:value-of select="nma:error-message"/>
	  </xsl:when>
	  <xsl:otherwise>
	    <xsl:value-of
		select="concat('Condition &quot;', @assert, '&quot; must be true')"/>
	  </xsl:otherwise>
	</xsl:choose>
      </xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <xsl:template match="nma:instance-identifier">
    <xsl:if test="not(@require-instance='false')">
      <xsl:element name="sch:let">
	<xsl:attribute name="name">pth</xsl:attribute>
	<xsl:attribute name="value">
	  <xsl:text>concat('</xsl:text>
	  <xsl:value-of select="$netconf-part"/>
	  <xsl:text>', .)</xsl:text>
	</xsl:attribute>
      </xsl:element>
      <xsl:element name="sch:assert">
	<xsl:attribute name="test">dyn:evaluate($pth)</xsl:attribute>
	<xsl:text>The instance "</xsl:text>
	<xsl:element name="sch:value-of">
	  <xsl:attribute name="select">$pth</xsl:attribute>
	</xsl:element>
	<xsl:text>" must exist.</xsl:text>
      </xsl:element>
    </xsl:if>
  </xsl:template>

  <xsl:template match="@nma:key">
    <xsl:call-template name="list-unique">
      <xsl:with-param name="tag" select="."/>
      <xsl:with-param
          name="message">Duplicate key</xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <xsl:template match="nma:unique">
    <xsl:call-template name="list-unique">
      <xsl:with-param name="tag" select="@tag"/>
      <xsl:with-param
          name="message">Violated uniqueness for</xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="list-unique">
    <xsl:param name="tag"/>
    <xsl:param name="message"/>
    <xsl:element name="sch:report">
      <xsl:attribute name="test">
        <xsl:text>preceding-sibling::</xsl:text>
        <xsl:call-template name="qname">
          <xsl:with-param name="name" select="../@name"/>
        </xsl:call-template>
        <xsl:text>[</xsl:text>
        <xsl:call-template name="check-dup-expr">
          <xsl:with-param name="nodelist" select="$tag"/>
        </xsl:call-template>
        <xsl:text>]</xsl:text>
      </xsl:attribute>
      <xsl:value-of select="concat($message, ' &quot;',$tag,'&quot;')"/>
    </xsl:element>
  </xsl:template>

  <xsl:template match="@nma:max-elements">
    <xsl:call-template name="element-count"/>
  </xsl:template>

  <xsl:template match="@nma:min-elements">
    <xsl:call-template name="element-count">
      <xsl:with-param name="ord">&gt;</xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <xsl:template match="@nma:when">
    <xsl:call-template name="assert-element">
      <xsl:with-param name="test">
	<xsl:text>ancestor-or-self::*[processing-instruction('dsrl')] or </xsl:text>
	<xsl:value-of select="concat('(',.,')')"/>
      </xsl:with-param>
      <xsl:with-param
          name="message"
          select="concat('Node &quot;', ../@name,
                  '&quot; is only valid when &quot;',.,'&quot;')"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template match="@nma:leafref">
    <xsl:element name="sch:report">
      <xsl:attribute name="test">
	<xsl:value-of select="concat('not(',.,'=.)')"/>
      </xsl:attribute>
      <xsl:text>Leaf &quot;</xsl:text>
      <xsl:call-template name="uproot"/>
      <xsl:text>&quot; does not exist for leafref value &quot;</xsl:text>
      <xsl:element name="sch:value-of">
	<xsl:attribute name="select">.</xsl:attribute>
      </xsl:element>
      <xsl:text>&quot;</xsl:text>
    </xsl:element>
  </xsl:template>

  <xsl:template match="@nma:leaf-list[.='true']">
    <xsl:element name="sch:report">
      <xsl:attribute name="test">
        <xsl:text>. = preceding-sibling::</xsl:text>
        <xsl:call-template name="qname">
          <xsl:with-param name="name" select="../@name"/>
        </xsl:call-template>
      </xsl:attribute>
      <xsl:text>Duplicate leaf-list entry &quot;</xsl:text>
      <xsl:element name="sch:value-of">
        <xsl:attribute name="select">.</xsl:attribute>
      </xsl:element>
      <xsl:text>&quot;.</xsl:text>
    </xsl:element>
  </xsl:template>

</xsl:stylesheet>
