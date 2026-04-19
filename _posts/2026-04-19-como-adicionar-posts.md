---
title: "como adicionar posts"
date: 2026-04-19
---

(só pra eu nao me esquecer mesmo)

posts vivem na pasta `_posts/` e seguem a convenção de nome:

```
YYYY-MM-DD-titulo-do-post.md
```

## front matter

todo post começa com um bloco de front matter entre `---`:

```yaml
---
title: "título do post"
date: 2026-04-19
---
```

- `title` — aparece na listagem e no topo do post
- `date` — define a ordem de exibição (mais recente primeiro)

## conteúdo

o restante do arquivo é markdown normal:

```markdown
# título

parágrafo com **negrito**, *itálico* e `código inline`.

## seção

- item um
- item dois

```python
print("bloco de código com syntax highlight")
```

> blockquote

---

[link](https://exemplo.com)
```

## publicar

1. cria o arquivo em `_posts/` seguindo o padrão de nome
2. faz commit e push pra `main`
3. o GitHub Actions builda e publica automaticamente

só isso.
