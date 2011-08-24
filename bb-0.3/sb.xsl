<?xml version="1.0"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
			      xmlns:bb="http://darkircop.org/bb"
			      exclude-result-prefixes="bb">

  <xsl:template match="field[@type='2']">
  	<type><xsl:value-of select="bb:hex2le32(text())" /></type>
  </xsl:template>

  <xsl:template match="field[@type='3']">
  	<name><xsl:value-of select="bb:hex2str(text())" /></name>
  </xsl:template>

  <xsl:template match="field[@type='5']">
  	<dsid><xsl:value-of select="bb:hex2str(text())" /></dsid>
  </xsl:template>

  <xsl:template match="field[@type='6']">
  	<userid><xsl:value-of select="bb:hex2le32(text())" /></userid>
  </xsl:template>

  <xsl:template match="field[@type='7']">
  	<uid><xsl:value-of select="bb:hex2str(text())" /></uid>
  </xsl:template>

  <xsl:template match="field[@type='8']">
  	<cid><xsl:value-of select="bb:hex2str(text())" /></cid>
  </xsl:template>

  <xsl:template match="field[@type='10']">
  	<compression><xsl:value-of select="bb:hex2le32(text())" /></compression>
  </xsl:template>

  <xsl:template match="field[@type='11']">
  	<encryption><xsl:value-of select="bb:hex2le32(text())" /></encryption>
  </xsl:template>

  <xsl:template match="field[@type='15']">
  	<description><xsl:value-of select="bb:hex2str(text())" /></description>
  </xsl:template>

  <xsl:template match="field[@type='17']">
  	<source><xsl:value-of select="bb:hex2le8(text())" /></source>
  </xsl:template>

  <xsl:template match="field[@type='19']">
  	<server><xsl:copy-of select="bb:hex2field(text())" /></server>
  </xsl:template>

  <xsl:template match="field[@type='22']">
  	<hrt><xsl:copy-of select="bb:hex2field(text())" /></hrt>
  </xsl:template>

  <xsl:template match="field[@type='23']">
  	<ruid><xsl:value-of select="bb:hex2le32(text(), 16)" /></ruid>
  </xsl:template>

  <xsl:template match="field[@type='9']">
  	<appdata><xsl:apply-templates/></appdata>
  </xsl:template>

  <xsl:template match="@*|node()">
  	<xsl:copy>
		<xsl:apply-templates select="@*|node()" />
	</xsl:copy>
  </xsl:template>

</xsl:stylesheet>
