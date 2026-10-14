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
                .background(Color.appSecondaryGroupedBackground)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Read aloud")
    }

    private func speak() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        #if canImport(UIKit)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = 0.5
        synthesizer.speak(utterance)
    }
}

