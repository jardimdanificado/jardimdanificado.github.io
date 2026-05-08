---
title: "Papagaio v0.32.9, Especificação."
date: 2026-05-08
---

# Papagaio: Agnostic Implementation Specification

Esta especificação descreve os requisitos fundamentais e a arquitetura necessária para implementar o motor Papagaio em qualquer linguagem ou ambiente.

---

## 1. Visão Geral da Arquitetura

O Papagaio é um processador de texto **multi-passagem (multi-pass)** que transforma um documento de entrada em um documento de saída através de uma pipeline de processamento. O estado do motor deve ser mantido em um **Contexto** global ou persistente durante o processamento.

### Pipeline de Execução
1.  **Prioridades:** Extração e execução recursiva de blocos `$priority`.
2.  **Pré-processador:** Resolução de símbolos, atribuições dinâmicas e variáveis de ambiente/CLI.
3.  **Registro de Padrões:** Extração de diretivas `$pattern` para uma lista global de regras.
4.  **Aplicação de Padrões:** Execução do motor de **Flex-Matching** para cada regra registrada.
5.  **Despacho de Comandos:** Execução de plugins (WASM/Host) e injeção de documentos.

---

## 2. O Motor de Flex-Matching

O diferencial do Papagaio é o "Flex-Matching", onde os espaços em branco entre os tokens de um padrão são tratados de forma elástica.

### Regras de Correspondência (Matching)
-   **Nomes de Variáveis:** Devem consistir em caracteres alfanuméricos e sublinhados (`isalnum` + `_`).
-   **Tokens Literais:** Devem corresponder exatamente ao texto, ignorando espaços em branco horizontais (` ` e `\t`) precedentes.
-   **Variáveis (`$var`):** Capturam texto de forma gananciosa (greedy). O limite da captura é definido pelo "Próximo Token" no padrão:
    -   Se o próximo token for um **Literal** ou **Bloco**, a variável captura até encontrar o início desse token ou uma quebra de linha (`\n`).
    -   Se o próximo token for outra **Variável**, a captura para no primeiro espaço em branco encontrado.
    -   Se não houver próximo token, a captura para na primeira quebra de linha (`\n`) ou no fim do documento.
-   **Espaço em Branco Elástico:** Entre dois tokens em um padrão, qualquer sequência de ` ` ou `\t` é aceita. Quebras de linha (`\n`) agem como delimitadores de segurança e não são saltadas automaticamente.
-   **Colapso de Espaço (`$` final):** Se um token terminar com o sigilo, o motor consome obrigatoriamente `[ \t\n\r]*`.

### Modificadores de Captura
O motor deve suportar validadores para variáveis:
-   **Inteiro/Float/Hex:** Validar caracteres específicos (hex permite prefixo `0x` ou `0X`).
-   **Binary:** Permite `0`, `1` e o marcador `b` ou `B`.
-   **Bloco:** Implementar um contador de profundidade para capturar conteúdo balanceado.
-   **Regex:** Delegar para um motor de expressões regulares (ex: `libregexp` ou similar).
-   **Filtros de String:** `starts`, `ends`, `prefix`, `suffix`, `infix`, `includes`.

---

## 3. Precedência e Iteração de Regras

Diferente de engines de regex tradicionais, o Papagaio aplica as regras de forma sequencial:
1.  As regras são aplicadas na ordem em que foram registradas no documento.
2.  A Regra 1 é aplicada em todo o documento. O resultado dessa transformação é passado para a Regra 2.
3.  Isso permite transformações em cascata (Ex: `A -> B`, depois `B -> C`).

---

## 4. Sistema de Substituição

Após uma correspondência bem-sucedida, a substituição ocorre gerando uma nova string:
1.  **Variáveis Simples:** Substituir `$name` pelo conteúdo capturado.
2.  **Variáveis Delimitadas:** Tratar `${name}` como `$name` para permitir sufixos imediatos.
3.  **Escapamento:** `$$` deve ser convertido para um único `$`.
4.  **Variáveis Opcionais:** Se uma variável `$opt?` não for capturada, ela deve ser substituída por uma string vazia.

---

## 5. O Pré-processador

Esta fase altera o comportamento do motor e o estado do contexto.

### Atribuição Dinâmica (`$NAME$from{content}`)
1.  O `content` deve ser processado recursivamente pelo motor.
2.  O resultado é armazenado como uma "regra de correspondência exata" para `$NAME`.
3.  A diretiva original é removida do texto de saída.

### Configuração de Símbolos (`$changesymbols`)
Permite redefinir os 4 pilares da sintaxe:
-   **Sigilo (Sigil):** O caractere que inicia comandos e variáveis (padrão: `$`).
-   **Delimitador de Abertura:** (padrão: `{`).
-   **Delimitador de Fechamento:** (padrão: `}`).
-   **Marcador Opcional:** (padrão: `?`).

---

---

## 6. Protocolo de Extensão WebAssembly (WASM/WAT)

A extensibilidade via WebAssembly é um requisito core do Papagaio. Qualquer implementação deve fornecer uma ponte de execução (bridge) seguindo este protocolo:

### Convenções de Exportação
O motor deve escanear o módulo WASM por funções exportadas que iniciem com o prefixo `papagaio_`.
-   Ex: Uma exportação `papagaio_greet` deve ser registrada como o comando `$greet`.

### Layout de Memória (A Ponte de Argumentos)
Os argumentos são passados para o WASM através da memória linear.
1.  **Base de Argumentos (`ARGS_BASE`):** Por padrão, reside no endereço `4096`.
2.  **Tabela de Ponteiros (`argv`):** Uma lista de inteiros de 32 bits (offsets) começando em `ARGS_BASE`. Cada entrada aponta para o início de uma string na memória.
3.  **Dados de String:** As strings (argumentos) devem ser escritas na memória logo após a tabela de ponteiros, terminadas em nulo (`\0`), e preferencialmente alinhadas em 8 bytes.

### Assinatura da Função
A função WASM deve ser chamada com a assinatura: `(i32, i32) -> i32`
-   **Parâmetro 1 (`argc`):** Quantidade de argumentos.
-   **Parâmetro 2 (`argv_ptr`):** O endereço base da tabela de ponteiros (`ARGS_BASE`).
-   **Retorno:** Um ponteiro (offset de 32 bits) para uma string terminada em nulo na memória do WASM contendo o resultado do processamento.

### Compilação Inline (WAT)
O motor deve integrar um compilador WAT (ex: `watr`) para permitir que strings de texto WebAssembly sejam compiladas e carregadas em tempo de execução através da diretiva `$wat{source}`.

### Funções do Host (Imports)
O ambiente deve fornecer, no mínimo, os seguintes imports para o módulo WASM (no namespace `env`):
-   `__host_write(ptr, len)`: Para debug/logs.
-   `__host_abort(msg_ptr)`: Para encerramento catastrófico.

---

## 7. Sistema de Plugins e Comandos

O Papagaio é agnóstico quanto à origem dos comandos.
1.  **Comandos Nativos:** Funções registradas na linguagem host.
2.  **Plugins (WASM):** O motor deve ser capaz de carregar binários e mapear exportações seguindo o protocolo da Seção 6.
3.  **Injeção de Arquivos:** `$file{path}` deve ler o sistema de arquivos e injetar o conteúdo bruto antes da fase de despacho.

---

## 8. Estado e Snapshots

O motor deve manter snapshots do documento para permitir introspecção:
-   **Original:** O texto de entrada imutável.
-   **Current:** O estado do texto no momento exato em que a diretiva `$document` é encontrada.

---

## 9. Dicas de Implementação (Agnóstico)

-   **StrView / Slices:** Use referências de string (ponteiros + tamanho) para evitar alocações excessivas durante o matching.
-   **Ordem de Regras:** Padrões definidos primeiro devem ter prioridade sobre padrões definidos depois (ordem de registro).
-   **Tratamento de \n:** Quebras de linha são sagradas; o motor nunca deve removê-las ou saltá-las a menos que explicitamente comandado pelo `$` final.
-   **Passagem de Argumentos para Comandos:** Os argumentos entre `{}` devem ser passados como uma lista de strings (`argv`) para o handler do comando.
