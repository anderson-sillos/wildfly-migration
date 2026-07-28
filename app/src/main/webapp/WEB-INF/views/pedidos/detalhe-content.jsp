<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ taglib prefix="migration" uri="http://asillos.com.br/migration/tags" %>
<article data-page="pedido-detalhe">
  <h1>Pedido <c:out value="${pedido.numero}"/></h1>
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
</article>
