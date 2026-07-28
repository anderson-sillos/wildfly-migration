<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ taglib prefix="migration" uri="http://asillos.com.br/migration/tags" %>
<section data-page="pedidos-lista" data-display-mode="<c:out value='${modoExibicao}'/>">
  <h1>Pedidos</h1>
  <c:choose>
    <c:when test="${empty pedidos}">
      <p>Nenhum pedido cadastrado.</p>
    </c:when>
    <c:otherwise>
      <table>
        <thead>
          <tr>
            <th>Número</th>
            <th>Cliente</th>
            <c:if test="${modoExibicao eq 'DETALHADO'}"><th>Descrição</th></c:if>
            <th>Valor</th>
            <th>Status</th>
          </tr>
        </thead>
        <tbody>
          <c:forEach items="${pedidos}" var="pedido">
            <c:url value="/pedidos/detalhe" var="detalheUrl">
              <c:param name="id" value="${pedido.id}"/>
            </c:url>
            <tr>
              <td><a href="<c:out value='${detalheUrl}'/>"><c:out value="${pedido.numero}"/></a></td>
              <td><c:out value="${pedido.clienteNome}"/></td>
              <c:if test="${modoExibicao eq 'DETALHADO'}"><td><c:out value="${pedido.descricao}"/></td></c:if>
              <td><fmt:formatNumber value="${pedido.valorTotal}" minFractionDigits="2" maxFractionDigits="2"/></td>
              <td><migration:statusPedido status="${pedido.status}"/></td>
            </tr>
          </c:forEach>
        </tbody>
      </table>
    </c:otherwise>
  </c:choose>
</section>
