import SwiftUI
import AVFoundation

struct SpeakerButton: View {
    var text: String
    var language: String

    @State private var synthesizer = AVSpeechSynthesizer()

    var body: some View {
        Button(action: {
            speak()
        }) {
            Image(systemName: "speaker.wave.2.circle.fill")
                .font(.system(size: 32)) // Duży, wyraźny przycisk
                .foregroundStyle(.blue.opacity(0.8))
                .background(.white)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func speak() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = 0.5
        synthesizer.speak(utterance)
    }
}

