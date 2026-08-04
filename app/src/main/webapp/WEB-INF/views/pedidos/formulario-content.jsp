<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="jakarta.tags.core" %>
<section data-page="pedidos-formulario">
  <h1>Novo pedido</h1>
  <c:if test="${not empty mensagemErro}">
    <p class="erro"><c:out value="${mensagemErro}"/></p>
  </c:if>
  <form action="<c:url value='/pedidos'/>" method="post">
    <label for="numero">Número</label>
    <input id="numero" name="numero" maxlength="32" required="required"
           value="<c:out value='${pedido.numero}'/>">
    <label for="clienteNome">Cliente</label>
    <input id="clienteNome" name="clienteNome" maxlength="120" required="required"
           value="<c:out value='${pedido.clienteNome}'/>">
    <label for="descricao">Descrição</label>
    <textarea id="descricao" name="descricao" maxlength="500"><c:out value="${pedido.descricao}"/></textarea>
    <label for="valorTotal">Valor total</label>
    <input id="valorTotal" name="valorTotal" inputmode="decimal" required="required">
    <p><button type="submit">Criar pedido</button></p>
  </form>
</section>
