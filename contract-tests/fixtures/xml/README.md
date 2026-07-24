# Fixtures de importação XML

- `pedido-valido.xml`: documento bem-formado que deve atender ao XSD;
- `pedido-invalido-xsd.xml`: bem-formado, mas viola pattern, tamanho, valor e
  enumeração do schema;
- `pedido-xxe.xml`: referencia uma entidade externa e deve ser rejeitado sem
  acessar o sistema de arquivos;
- `pedido-entidades-expansivas.xml`: contém expansão de entidades e deve ser
  rejeitado antes de expandi-las.

Os dois últimos arquivos são deliberadamente hostis. Não os abra com um parser
que permita `DOCTYPE`, entidades externas, DTD externa ou resolução de recursos
de rede. Os testes modernos devem comprovar que nenhuma leitura externa ocorre.
