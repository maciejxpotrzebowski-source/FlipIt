import SwiftUI

struct CardView: View {
    var text: String
    var label: String      // Np. "Słówko" lub "Definicja"
    var language: String   // Kod języka dla głośnika
    var displayLabel: String {
        "\(label) (\(getLangCode(language)))"
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.appSecondaryGroupedBackground)
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)

            VStack(spacing: 0) {
                // 1. LABEL NA GÓRZE (małymi literami)
                Text(displayLabel)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                    .padding(.top, 32)

                Spacer()

                // 2. GŁÓWNA TREŚĆ
                Text(text)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.5)

                Spacer()
                // 3. GŁOŚNIK (pod słowem)
                SpeakerButton(text: text, language: language)
                    .padding(.bottom, 64)
            }
        }
        .frame(height: 400)
    }
}

