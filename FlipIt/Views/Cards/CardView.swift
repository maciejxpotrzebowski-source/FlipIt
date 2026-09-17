import SwiftUI

struct CardView: View {
    var text: String
    var label: String      // Np. "Słówko" lub "Definicja"
    var language: String   // Kod języka dla głośnika
    var backgroundColor: Color
    var displayLabel: String {
            "\(label) (\(getLangCode(language)))"
        }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(backgroundColor)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)

            VStack(spacing: 0) {
                // 1. LABEL NA GÓRZE (małymi literami)
                Text(displayLabel)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .textCase(.uppercase)
                    .foregroundStyle(.gray)
                    .padding(.top, 32)

                Spacer()

                // 2. GŁÓWNA TREŚĆ
                Text(text)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .foregroundStyle(.black)
                    .minimumScaleFactor(0.5)

                Spacer()
                // 3. GŁOŚNIK (pod słowem)
                SpeakerButton(text: text, language: language)
                    .padding(.bottom, 64)
                //Spacer()
            }
        }
        .frame(height: 400)
    }
}

