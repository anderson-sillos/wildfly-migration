# INC-009 — configuração padrão tenta criar keystore HTTPS desnecessário

## Identificação

- checkpoint: `CP-2B`;
- origem: runtime WildFly 9 do laboratório limitado a HTTP em loopback;
- destino: `standalone.xml` original do WildFly 26.1.3.Final;
- etapa: `startup`;
- categoria: configuração de segurança;
- reprodução: `natural`;
- estado: aberto.

## Assinatura sanitizada

```text
WFLYELY00023: KeyStore file application.keystore does not exist.
WFLYELY01084: KeyStore will be auto generated with a self-signed certificate.
```

## Causa-raiz

A configuração completa do WildFly 26 inclui listener HTTPS e contexto SSL
com keystore autogerado. A aplicação do laboratório não declara
`security-constraint`, `login-config` nem domínio próprio e seus testes locais
precisam somente do listener HTTP em loopback.

## Menor correção planejada

Remover somente o listener HTTPS da cópia temporária do runtime usada pelo
laboratório, mantendo management e HTTP ligados a loopback. Não criar,
versionar ou reutilizar um keystore apenas para ocultar o aviso.

## Aplicação equivalente no sistema real

Não remova HTTPS automaticamente de produção. Inventarie proxy, TLS,
autenticação, realms, certificados e políticas existentes e migre-os
explicitamente. A correção deste laboratório é válida porque HTTPS está fora
do contrato e nenhuma interface pública é exposta.

## Teste de regressão

O runtime corrigido não deve abrir a porta HTTPS nem emitir `WFLYELY00023` ou
`WFLYELY01084`; management e HTTP devem continuar restritos a loopback.

## Rollback

Descarte a cópia temporária corrigida. A distribuição externa original do
WildFly 26 permanece imutável.
