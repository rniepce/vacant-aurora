# Recursos gráficos da ficha (Play Store)

Arquivos-base em SVG para a ficha do Google Play. Exporte para **PNG** antes de subir.

| Arquivo | Uso no Play Console | Tamanho final |
|---|---|---|
| `icon-512.svg` | Ícone do app | 512×512 PNG |
| `feature-graphic-1024x500.svg` | Gráfico de destaque | 1024×500 PNG |

## Como exportar SVG → PNG (Mac)

Opção rápida pelo terminal (se tiver o `rsvg-convert` ou `cairosvg`):

```bash
# com librsvg (brew install librsvg)
rsvg-convert -w 512 -h 512 icon-512.svg -o icon-512.png
rsvg-convert -w 1024 -h 500 feature-graphic-1024x500.svg -o feature-graphic.png
```

Sem ferramentas: abra o `.svg` no navegador, ou use um conversor online
(ex.: cloudconvert.com), garantindo as dimensões exatas acima.

> Alternativa para o ícone: Android Studio → botão direito em `res` →
> New → Image Asset gera o ícone nos tamanhos certos automaticamente.

## Capturas de tela (você gera)

2 a 8 prints do app rodando. Dica: na tela inicial, **segure (long-press) o
título "Radar de Preços"** para carregar dados de exemplo e tirar prints do
painel e da tela de detalhe com histórico.
