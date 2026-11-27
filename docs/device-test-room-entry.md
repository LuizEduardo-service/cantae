# Roteiro de teste no aparelho — Criar sala e Entrar em sala

Confirma nos celulares o que o computador não consegue provar: o anúncio da sala no Wi‑Fi (mDNS/Bonjour), as permissões de rede local, o atalho "Abrir ajustes" e a conexão entre dois aparelhos de verdade (spec `.specs/features/room-entry/spec.md`; ROOM-20, 37, 49, 50, 57).

**Situação:** ainda não executado. Ao executar, anote para cada passo "ok" ou o que aconteceu, o modelo dos aparelhos e a versão do sistema, e registre o resultado em `.specs/STATE.md`.

## Preparação

- Dois celulares no **mesmo Wi‑Fi** (de casa ou do ensaio, não a rede de visitantes de um prédio, que costuma isolar os aparelhos). O ideal é um Android 8 ou mais novo e um iPhone com iOS 14 ou mais novo; o iPhone precisa de um Mac com Xcode.
- Um terceiro celular, se houver, para o passo de recusa.
- No celular do Mestre, uma música na biblioteca (por exemplo, "Ave Verum Corpus", Mozart).
- Instalar a versão de **release** nos dois: `flutter run --release -d <aparelho>`. É a versão de release que confirma a permissão de rede no Android (ROOM-49).

## Passos

1. **Mestre (Android):** na Biblioteca, tocar "Criar sala".
   - **Esperado:** a folha "Como você quer aparecer na sala?". Digitar "Marina" e tocar "Salvar nome". Aparece "Gerando código" e, em seguida, o código de 4 dígitos, a pílula "Visível neste Wi‑Fi" e "Ninguém pediu para entrar ainda".
2. **Mestre:** tocar "Copiar".
   - **Esperado:** o aviso "Código copiado"; colar em outro app mostra o mesmo código.
3. **Mestre:** tocar "Escolher música" e escolher "Ave Verum Corpus".
   - **Esperado:** a linha "Música" mostra o nome e o botão vira "Trocar".
4. **Cantor (iPhone):** na Biblioteca, tocar "Entrar em sala".
   - **Esperado:** a folha de nome. Digitar "Ana" e salvar. O iOS pergunta se o Cantaê pode acessar a rede local, com a frase "O Cantaê usa a rede Wi‑Fi local para encontrar a sala do ensaio e tocar junto com o coral." Tocar "Permitir".
5. **Cantor:** esperar a lista.
   - **Esperado:** em poucos segundos, um card "Sala de Marina" com "Ave Verum Corpus" e **sem o código**.
6. **Cantor:** tocar o card e digitar um código errado; tocar "Entrar".
   - **Esperado:** a frase "Digite o código que aparece na tela de Marina." ao tocar o card; depois, borda vermelha no campo e "Código não encontrado". "Digitar de novo" limpa o campo.
7. **Cantor:** digitar o código certo e tocar "Entrar".
   - **Esperado:** "Aguardando Marina aprovar", o card com borda verde e o campo desativado. **Mestre:** "Pedindo para entrar · 1" com "Ana".
8. **Mestre:** tocar "Aprovar".
   - **Esperado:** no Mestre, Ana em "Na sala · 1 de 8". No cantor, "Você está na sala de Marina".
9. **Terceiro celular, se houver:** pedir entrada com o código certo. **Mestre:** tocar "Recusar".
   - **Esperado:** o terceiro celular mostra "Entrada recusada" com "Escolher outra sala".
10. **Mestre:** tocar "Começar a conduzir".
    - **Esperado:** a sala provisória "Sala <código>", com "Você · Mestre" e "Ana · Cantor". O código não muda.
11. **Cantor:** tocar "Sair da sala".
    - **Esperado:** o cantor volta à Biblioteca; no Mestre, Ana some da lista.
12. **Cantor:** entrar de novo (passos 4 a 8, sem a folha de nome). **Mestre:** tocar "Encerrar sala" e confirmar.
    - **Esperado:** o Mestre volta à Biblioteca. O cantor volta à Biblioteca com o aviso "A sala foi encerrada ou a conexão caiu." O card da sala some da lista de quem procura.
13. **Pedido sem resposta:** com uma sala criada, pedir entrada no cantor e não responder no Mestre por 60 segundos.
    - **Esperado:** no cantor, "O Mestre não respondeu" com "Tentar de novo"; no Mestre, o pedido some.
14. **Permissão negada no iOS:** em Ajustes › Privacidade › Rede Local, desligar o Cantaê. Abrir "Entrar em sala" no iPhone.
    - **Esperado:** depois de 10 segundos, "Nenhuma sala neste Wi‑Fi" com a frase "Se você negou o acesso à rede local, libere nos ajustes." e o botão "Abrir ajustes", que abre a página do Cantaê nos Ajustes.
15. **Android:** com o celular em modo avião e o Wi‑Fi desligado, tocar "Criar sala".
    - **Esperado:** um banner de erro ("Não foi possível criar a sala." com "Tentar de novo", ou "Sem acesso à rede local" com "Abrir ajustes", que abre a página do Cantaê). Anotar qual apareceu: o sistema decide a causa.
16. **Android, bateria:** depois de sair de "Entrar em sala", deixar o celular parado 10 minutos.
    - **Esperado:** nenhum uso de bateria do Cantaê em segundo plano em Configurações › Bateria (o bloqueio de multicast foi solto ao parar a busca, ROOM-50).

## O que registrar no STATE.md

- Aparelhos e versões.
- Passos com resultado diferente do esperado.
- No passo 15, qual banner apareceu.
