# Testes de contrato

Esta área receberá a suíte externa que exercita a aplicação pela interface HTTP
e pelo estado persistido, sem importar classes internas do WAR.

A implementação executável começa no CP-1E. Os fixtures estáticos definidos no
CP-1B ficam em [`fixtures/`](fixtures/) e preservam a fronteira arquitetural
entre testes de contrato e testes internos de `app/`.
