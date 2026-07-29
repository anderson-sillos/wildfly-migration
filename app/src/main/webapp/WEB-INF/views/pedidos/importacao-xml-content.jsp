<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<section data-page="pedidos-importacao-xml">
  <h1>Importar pedido por XML</h1>
  <p>
    Selecione um documento compatível com o XSD do laboratório.
    O limite do arquivo é 128 KiB.
  </p>
  <form action="<c:url value='/pedidos/importar-xml'/>" method="post"
        enctype="multipart/form-data" data-xml-import-form="legacy">
    <label for="arquivoXml">Arquivo XML</label>
    <input id="arquivoXml" name="arquivoXml" type="file"
           accept=".xml,application/xml,text/xml" required="required">
    <p><button type="submit">Importar pedido</button></p>
  </form>
</section>
