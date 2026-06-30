# Status da publicação — Radar de Preços (Android)

Onde paramos no caminho até o Google Play. Atualizado em 26/06/2026.

## Dados do projeto
- **App ID (permanente):** `com.rafaelpimentel.radarprecos`
- **Nome:** Radar de Preços (PT) / Price Radar (EN)
- **Conta Play Console:** criada (conta pessoal, ID 5102890828998436593)
- **PR:** https://github.com/rniepce/vacant-aurora/pull/2
- **Política de privacidade (após ativar Pages):** https://rniepce.github.io/vacant-aurora/

## Checklist

| # | Etapa | Status |
|---|---|---|
| 1 | App nativo completo e testado (login + leitura do carrinho) | ✅ feito |
| 2 | Toolchain 2026 (AGP 9.2 / Gradle 9.4.1 / Kotlin 2.2.10) | ✅ feito |
| 3 | Ícone adaptável + nome + App ID definitivo | ✅ feito |
| 4 | Chave de assinatura (`.jks`) criada | ✅ feito |
| 5 | `.aab` de release assinado gerado | ✅ feito |
| 6 | Conta de desenvolvedor Play Console criada (US$ 25) | ✅ feito |
| 7 | Política de privacidade escrita (`docs/index.html`) | ✅ feito |
| 8 | Textos da ficha PT/EN (`PLAY_STORE.md`) | ✅ feito |
| 9 | Recursos gráficos base (`store-assets/`) | ✅ feito |
| 10 | **Verificação de dispositivo Android real** | ⛔ **BLOQUEADO** |
| 11 | Ativar GitHub Pages (1 clique em Settings → Pages) | ⏳ pendente |
| 12 | Exportar gráficos SVG → PNG (ícone 512, banner 1024×500) | ✅ feito |
| 13 | Tirar capturas de tela (long-press no título p/ modo demo) | ⏳ pendente |
| 14 | Criar o app no Console + preencher ficha + subir `.aab` | ⏳ depende do #10 |
| 15 | Teste Interno → validar → enviar para revisão | ⏳ depende do #10 |

## 🔴 Bloqueio atual (#10)

A verificação de dispositivo do Play Console **exige um Android físico** rodando
Android 10+. **Emuladores não passam** (a checagem usa atestação de hardware; a
mensagem de erro sobre "SDK 29" é enganosa — testado num Pixel 10 Pro XL API 37
e mesmo assim recusou).

**Como destravar:** pegar um Android emprestado por ~2 min →
instalar o app "Google Play Console" (Play Store) → entrar com `rniepce@gmail.com`
→ a verificação completa. Depois pode deslogar.

## ⚠️ Próximo bloqueio previsto

Conta pessoal nova exige, antes da **produção** (loja pública):
**teste fechado com 20 testadores por 14 dias**. O **Teste Interno** (até 100
pessoas por link) não tem essa exigência e serve para validar antes.

## Local dos arquivos-chave
- Build de release: `app/build/outputs/bundle/release/app-release.aab`
- Guia completo: `PLAY_STORE.md`
- Gráficos: `store-assets/`
- Política: `docs/index.html`
- Chave de assinatura: guardada por você (fora do git) — **fazer backup!**
