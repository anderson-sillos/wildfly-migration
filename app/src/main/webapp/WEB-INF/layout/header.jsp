<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<header>
  <div>
    <strong>WildFly Migration Lab</strong>
    <nav>
      <a href="<c:url value='/pedidos'/>">Pedidos</a>
      <a href="<c:url value='/pedidos/novo'/>">Novo pedido</a>
      <a href="<c:url value='/pedidos/importar-xml'/>">Importar XML</a>
    </nav>
  </div>
  <form action="<c:url value='/preferencia'/>" method="post">
    <label for="modoExibicao">Exibição</label>
    <select id="modoExibicao" name="modoExibicao">
      <option value="DETALHADO"<c:if test="${modoExibicao eq 'DETALHADO'}"> selected="selected"</c:if>>Detalhada</option>
      <option value="COMPACTO"<c:if test="${modoExibicao eq 'COMPACTO'}"> selected="selected"</c:if>>Compacta</option>
    </select>
    <button type="submit">Aplicar</button>
  </form>
</header>
