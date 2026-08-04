<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="jakarta.tags.core" %>
<section data-page="erro-controlado">
  <h1>Não foi possível concluir a operação</h1>
  <p class="erro"><c:out value="${mensagemErro}"/></p>
  <c:if test="${not empty correlationId}">
    <p>Correlação: <code><c:out value="${correlationId}"/></code></p>
  </c:if>
</section>
