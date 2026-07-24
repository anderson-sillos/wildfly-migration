# Segurança do laboratório

O baseline reproduz componentes deliberadamente obsoletos. Ele serve apenas para
laboratório local e não deve ser exposto à internet nem tratado como modelo de
produção.

## Controles obrigatórios

- Bind do runtime legado somente em `127.0.0.1`, `localhost`, `::1` ou rede
  interna isolada.
- Credenciais Oracle fornecidas por ambiente ou secret local ignorado.
- Binários proprietários fornecidos externamente e validados por checksum.
- Nenhuma publicação de `.env`, wallet, chave privada, token ou driver restrito.
- Evidências registram nomes de variáveis e estado da validação, nunca valores.

## Incidente com segredo

Não abra uma issue pública contendo o valor. Interrompa o push, revogue ou
rotacione a credencial no sistema de origem e remova o material do histórico
antes de prosseguir. Registre apenas o tipo de segredo, o arquivo afetado e a
confirmação da rotação.

Vulnerabilidades observadas exclusivamente nos componentes históricos devem ser
documentadas como risco do laboratório; elas não justificam expor o runtime nem
redistribuir os binários.
