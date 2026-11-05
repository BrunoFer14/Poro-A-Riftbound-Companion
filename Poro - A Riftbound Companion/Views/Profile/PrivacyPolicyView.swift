import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Group {
                    Text("Política de Privacidade")
                        .font(.title2.bold())
                    Text("Última atualização: Abril de 2026")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                policySection(
                    title: "1. Dados que recolhemos",
                    body: """
                    • Endereço de email e nome de utilizador (autenticação)
                    • Coleção de cartas e decks (sincronização entre dispositivos)
                    • Anúncios publicados no mercado (carta, preço, localização, condição)
                    • Mensagens trocadas entre utilizadores no mercado
                    • Localização aproximada (apenas quando usas o filtro "Perto de mim" — nunca em segundo plano)
                    • Token de notificações push (para receberes mensagens)
                    """
                )

                policySection(
                    title: "2. Como usamos os dados",
                    body: """
                    Os dados são utilizados exclusivamente para o funcionamento da app:
                    • Sincronizar a tua coleção e decks entre dispositivos
                    • Mostrar e gerir os teus anúncios no mercado
                    • Permitir comunicação entre compradores e vendedores
                    • Enviar notificações de novas mensagens
                    Não vendemos nem partilhamos os teus dados com terceiros para fins publicitários.
                    """
                )

                policySection(
                    title: "3. Armazenamento",
                    body: """
                    Os dados são armazenados de forma segura no Google Firebase (Firestore e Authentication), sujeito à política de privacidade da Google. Os dados de coleção e decks também são guardados localmente no dispositivo.
                    """
                )

                policySection(
                    title: "4. Os teus direitos",
                    body: """
                    Podes a qualquer momento:
                    • Eliminar a tua conta e todos os dados associados através do Perfil
                    • Remover anúncios e conversas do mercado
                    • Revogar permissões (localização, notificações) nas definições do iOS
                    """
                )

                policySection(
                    title: "5. Menores",
                    body: "Esta app não se destina a menores de 13 anos. Não recolhemos dados de menores de forma intencional."
                )

                policySection(
                    title: "6. Contacto",
                    body: "Para questões sobre privacidade, contacta-nos através da App Store ou pelo email indicado no perfil da app."
                )
            }
            .padding()
        }
        .navigationTitle("Política de Privacidade")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func policySection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
