<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ taglib prefix="migration" uri="http://asillos.com.br/migration/tags" %>
<article data-page="pedido-detalhe">
  <h1>Pedido <c:out value="${pedido.numero}"/></h1>
  <c:if test="${importacaoConcluida}">
    <p data-xml-import-status="ok">Pedido importado por XML com sucesso.</p>
  </c:if>
  <dl>
    <dt>Cliente</dt>
    <dd><c:out value="${pedido.clienteNome}"/></dd>
    <dt>Descrição</dt>
    <dd><c:out value="${pedido.descricao}"/></dd>
    <dt>Valor total</dt>
    <dd><fmt:formatNumber value="${pedido.valorTotal}" minFractionDigits="2" maxFractionDigits="2"/></dd>
    <dt>Status</dt>
    <dd><migration:statusPedido status="${pedido.status}"/></dd>
  </dl>

  <section aria-labelledby="anexos-titulo">
    <h2 id="anexos-titulo">Anexos</h2>
    <c:if test="${uploadConcluido}">
      <p data-upload-status="ok">Anexo incluído com sucesso.</p>
    </c:if>

    <c:url var="uploadUrl" value="/anexos/upload">
      <c:param name="pedidoId" value="${pedido.id}"/>
    </c:url>
    <form action="${uploadUrl}" method="post"
          enctype="multipart/form-data" data-upload-form="legacy">
      <label for="arquivo">Arquivo</label>
      <input id="arquivo" name="arquivo" type="file" required="required">
      <p>Limites: 512 KiB por arquivo e 576 KiB por requisição.</p>
      <p><button type="submit">Anexar</button></p>
    </form>

    <c:choose>
      <c:when test="${empty anexos}">
        <p data-anexos-vazios="true">Nenhum anexo.</p>
      </c:when>
      <c:otherwise>
        <table>
          <thead>
            <tr>
              <th>Nome</th>
              <th>Tipo</th>
              <th>Bytes</th>
              <th>SHA-256</th>
              <th>Criado em</th>
            </tr>
          </thead>
          <tbody>
            <c:forEach var="anexo" items="${anexos}">
              <tr data-anexo-id="<c:out value='${anexo.id}'/>">
                <td data-anexo-nome="<c:out value='${anexo.nomeArquivo}'/>"><c:out value="${anexo.nomeArquivo}"/></td>
                <td><c:out value="${anexo.tipoConteudo}"/></td>
                <td><c:out value="${anexo.tamanhoBytes}"/></td>
                <td><code><c:out value="${anexo.sha256}"/></code></td>
                <td><fmt:formatDate value="${anexo.criadoEm}" pattern="yyyy-MM-dd HH:mm:ss"/></td>
              </tr>
            </c:forEach>
          </tbody>
        </table>
      </c:otherwise>
    </c:choose>
  </section>
</article>
