<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="tiles" uri="http://tiles.apache.org/tags-tiles" %>
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title><tiles:getAsString name="title"/></title>
  <style>
    body { color: #1d2733; font-family: sans-serif; margin: 0; }
    header, main, footer { margin: auto; max-width: 960px; padding: 1rem; }
    header { align-items: center; display: flex; gap: 1rem; justify-content: space-between; }
    nav a { margin-right: .75rem; }
    table { border-collapse: collapse; width: 100%; }
    th, td { border-bottom: 1px solid #ccd3da; padding: .6rem; text-align: left; }
    label { display: block; margin-top: .75rem; }
    input, textarea, select, button { font: inherit; }
    input, textarea { box-sizing: border-box; max-width: 40rem; padding: .4rem; width: 100%; }
    .erro { background: #ffe9e9; border: 1px solid #b52626; padding: .75rem; }
    .status { border-radius: .25rem; display: inline-block; padding: .2rem .45rem; }
    .status-novo { background: #fff0b3; }
    .status-aprovado { background: #ccebd6; }
    .status-cancelado { background: #ffd1d1; }
  </style>
</head>
<body>
  <tiles:insertAttribute name="header"/>
  <main>
    <tiles:insertAttribute name="body"/>
  </main>
  <tiles:insertAttribute name="footer"/>
</body>
</html>
