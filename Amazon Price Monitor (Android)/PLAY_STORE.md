# Publicação no Google Play — Radar de Preços

Guia completo para publicar o app. Itens marcados com 🔧 já estão prontos no projeto;
os demais você faz na sua conta do Google Play Console.

- **App ID (permanente):** `com.rafaelpimentel.radarprecos`
- **Nome do app:** Radar de Preços
- **Política de Privacidade:** https://rniepce.github.io/vacant-aurora/ (após ativar o GitHub Pages — ver abaixo)

---

## 1. 🔧 Build de release (já configurado)

O projeto já está pronto para gerar um App Bundle assinado:
- `applicationId` definido e `minifyEnabled` (R8) ligado no build de release.
- Assinatura lida de `keystore.properties` (que NÃO vai para o git).

### Criar a chave de assinatura (uma vez só)

No Terminal, dentro de `Amazon Price Monitor (Android)/`:

```bash
keytool -genkey -v -keystore radar-precos-release.jks \
    -keyalg RSA -keysize 2048 -validity 10000 -alias radarprecos
```

Guarde **muito bem** o arquivo `.jks` e as senhas — se perder, não dá para atualizar o app depois.

Depois copie o template e preencha:

```bash
cp keystore.properties.template keystore.properties
# edite keystore.properties com suas senhas reais
```

### Gerar o App Bundle (.aab)

No Android Studio: **Build → Generate Signed App Bundle / APK → Android App Bundle**,
ou pelo terminal:

```bash
./gradlew bundleRelease
# saída: app/build/outputs/bundle/release/app-release.aab
```

---

## 2. Ativar a Política de Privacidade (GitHub Pages)

1. No GitHub, abra o repositório → **Settings → Pages**.
2. Em "Build and deployment", **Source: Deploy from a branch**.
3. Selecione a branch `claude/ios-price-radar-review-3vtkl2` (ou `main` depois do merge) e a pasta **`/docs`**. Salve.
4. Em ~1 min a política fica no ar em **https://rniepce.github.io/vacant-aurora/**.

Use essa URL no campo "Política de Privacidade" do Play Console.

---

## 3. Conta e ficha no Play Console

1. Crie a conta de desenvolvedor em https://play.google.com/console (taxa única US$ 25).
2. **Create app** → nome "Radar de Preços", idioma padrão Português (Brasil), tipo App, Gratuito.
3. Preencha os formulários obrigatórios:
   - **Política de Privacidade:** a URL do passo 2.
   - **Segurança de dados:** declare que o app **não coleta nem compartilha dados**
     (tudo é local). Isso bate com a política de privacidade.
   - **Classificação de conteúdo:** responda o questionário (sem conteúdo sensível → Livre).
   - **App de governo / anúncios:** marque "sem anúncios".
   - **Público-alvo:** maiores de 13/18 (não direcionado a crianças).

---

## 4. Recursos gráficos da ficha (você precisa criar)

| Recurso | Especificação | Como obter |
|---|---|---|
| Ícone | 512×512 PNG | Android Studio → botão direito em `res` → New → Image Asset |
| Gráfico de destaque | 1024×500 PNG | Banner simples com o nome do app |
| Capturas de tela do celular | 2 a 8, mín. 320px | Rode o app e tire prints (telas do painel e do detalhe) |

> Dica: para boas capturas, **segure (long-press) o título "Radar de Preços"** na tela inicial —
> isso carrega itens de exemplo (iPhone, PS5, Kindle, Echo Dot) com histórico de preços,
> perfeito para os prints da loja. É um atalho discreto, invisível para o usuário comum.

---

## 5. Textos da ficha (prontos para copiar)

**Título (até 30 caracteres):**
```
Radar de Preços
```

**Descrição curta (até 80 caracteres):**
```
Monitore quedas de preço dos itens do seu carrinho da Amazon e seja avisado.
```

**Descrição completa (até 4000 caracteres):**
```
Radar de Preços acompanha os preços dos itens que estão no seu carrinho da
Amazon.com.br e avisa você quando algum cai de preço.

COMO FUNCIONA
• Faça login na sua conta da Amazon com segurança (direto na página oficial da Amazon).
• Toque em Atualizar para ler os itens do seu carrinho.
• O app registra o histórico de preços de cada produto ao longo do tempo.
• Receba uma notificação quando um item tiver queda significativa de preço.

RECURSOS
• Histórico de preços com menor e maior valor de cada item.
• Ordenação por maior queda ou menor preço.
• Verificação automática em segundo plano.
• Tudo funciona localmente no seu aparelho — nenhum dado é enviado para servidores.
• Disponível em português e inglês.

PRIVACIDADE
O app não coleta nem compartilha nenhum dado pessoal. Seu login é feito na própria
página da Amazon e o histórico fica apenas no seu dispositivo.

Radar de Preços não é afiliado nem endossado pela Amazon.
```

---

### Textos da ficha em inglês (para adicionar como idioma "English (United States)")

**Title (max 30 chars):**
```
Price Radar
```

**Short description (max 80 chars):**
```
Track price drops on items in your Amazon cart and get notified instantly.
```

**Full description (max 4000 chars):**
```
Price Radar keeps an eye on the prices of items in your Amazon.com.br cart and
alerts you whenever one drops.

HOW IT WORKS
• Sign in securely to your Amazon account (directly on Amazon's official page).
• Tap Refresh to read the items in your cart.
• The app records each product's price history over time.
• Get a notification when an item has a meaningful price drop.

FEATURES
• Price history with the lowest and highest value for each item.
• Sort by biggest drop or lowest price.
• Automatic background checks.
• Everything runs locally on your device — no data is sent to any server.
• Available in English and Portuguese.

PRIVACY
The app does not collect or share any personal data. Your login happens on
Amazon's own page and your history stays only on your device.

Price Radar is not affiliated with or endorsed by Amazon.
```

---

## 6. Enviar para revisão

1. **Testing → Internal testing** (recomendado começar aqui): suba o `.aab`, adicione seu
   e-mail como testador, gere o link e instale no seu celular para validar.
2. Quando estiver satisfeito: **Production → Create new release**, suba o `.aab`, revise e
   **Send for review**. A análise costuma levar de algumas horas a alguns dias.

---

## ⚠️ Observação importante sobre a revisão

Como o app automatiza a leitura de um site de terceiros (Amazon), há chance de o Google
pedir esclarecimentos ou de a Amazon questionar o uso da marca/scraping. Para reduzir riscos:
- Deixe claro na ficha que o app **não é afiliado à Amazon** (já incluído nos textos).
- Não use o logotipo da Amazon nos recursos gráficos.
- Mantenha a declaração de "não coleta de dados" coerente com a política de privacidade.
