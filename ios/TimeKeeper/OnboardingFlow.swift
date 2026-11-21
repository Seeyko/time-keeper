import SwiftUI
import FamilyControls

enum OnboardingStep: Int, CaseIterable {
    case welcome, hours, aha, how, goals, access, apps, minutes, notify, site, lock, ready
}

enum PhoneHours: Int, CaseIterable, Identifiable {
    case two = 2, four = 4, six = 6, eight = 8

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .two: "Moins de 2 h"
        case .four: "2 à 4 h"
        case .six: "4 à 6 h"
        case .eight: "Plus de 6 h"
        }
    }

    var daily: Double {
        switch self {
        case .two: 1.5
        case .four: 3
        case .six: 5
        case .eight: 7
        }
    }

    var daysPerYear: Int { Int((daily * 365 / 24).rounded()) }
}

enum OnboardingGoal: String, CaseIterable, Identifiable {
    case social, video, games, site

    var id: String { rawValue }

    var label: String {
        switch self {
        case .social: "Réseaux sociaux"
        case .video: "Vidéos"
        case .games: "Jeux"
        case .site: "Un site"
        }
    }
}

struct OnboardingFlow: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject private var auth = AuthorizationCenter.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var step: OnboardingStep = .welcome
    @State private var goal: OnboardingGoal = .social
    @State private var selection = FamilyActivitySelection()
    @State private var minutes = 30
    @State private var site = ""
    @State private var siteInvalid = false
    private let dayStart = DayStart(hour: 4, minute: 0)
    @State private var lock = false
    @State private var hours: PhoneHours = .four
    @State private var requesting = false
    @State private var showPicker = false
    @State private var accessDenied = false
    @State private var demoPicked = false

    private var flow: [OnboardingStep] {
        OnboardingStep.allCases.filter { step in
            switch step {
            case .apps, .minutes, .notify: goal != .site
            case .site: goal == .site
            default: true
            }
        }
    }

    private var limitName: String { goal.label }

    private var appsChosen: Bool {
        model.demo ? demoPicked : !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty || !selection.webDomainTokens.isEmpty
    }

    private var swap: AnyTransition { reduceMotion ? .opacity : AnyTransition(.blurReplace) }

    var body: some View {
        VStack(spacing: 0) {
            header
            ZStack {
                content
                    .id(step)
                    .transition(swap)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 24)
            footer
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .smooth(duration: 0.35), value: step)
        .familyActivityPicker(isPresented: $showPicker, selection: $selection)
        .tint(Theme.accent)
    }

    private var position: Int { flow.firstIndex(of: step) ?? 0 }

    private var header: some View {
        HStack(spacing: 12) {
            if position > 1 {
                Button {
                    go(-1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.semibold))
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Retour")
            }
            if position > 1 {
                ProgressView(value: Double(position), total: Double(flow.count - 1))
                    .tint(Theme.accent)
                    .padding(.trailing, 44)
                    .accessibilityHidden(true)
            }
        }
        .frame(height: 44)
        .padding(.horizontal, 8)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome: welcome
        case .hours: hoursStep
        case .aha: aha
        case .how: how
        case .goals: goalsStep
        case .access: access
        case .apps: apps
        case .minutes: minutesStep
        case .site: siteStep
        case .notify: notifyStep
        case .lock: lockStep
        case .ready: ready
        }
    }

    private var welcome: some View {
        VStack(spacing: 20) {
            Spacer()
            Owl(name: "owl-garde", label: "Le hibou de Time Keeper croise les ailes", height: 190)
            Text("Ta limite va enfin tenir.")
                .font(Theme.title)
                .multilineTextAlignment(.center)
            Spacer()
        }
    }

    private var hoursStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            StepTitle("Combien de temps sur ton téléphone, par jour ?")
                .padding(.bottom, 12)
            ForEach(PhoneHours.allCases) { option in
                Choice(label: option.label, on: hours == option) { hours = option }
            }
        }
    }

    private var aha: some View {
        VStack(spacing: 16) {
            Spacer()
            CountUp(target: hours.daysPerYear)
            Text("jours par an sur ton téléphone.")
                .font(Theme.heading)
                .multilineTextAlignment(.center)
            Text("Time Keeper t'en rend une partie.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }

    private var how: some View {
        VStack(spacing: 18) {
            StepTitle("Quand ton temps est fini, l'app se ferme.", line: "Pas de bouton « Encore 5 minutes ». Rien à contourner.")
                .padding(.top, 8)
            ShieldPreview()
            Spacer(minLength: 0)
        }
    }

    private var goalsStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            StepTitle("Qu'est-ce qui te prend le plus de temps ?")
                .padding(.bottom, 12)
            ForEach(OnboardingGoal.allCases) { option in
                Choice(label: option.label, on: goal == option) { goal = option }
            }
        }
    }

    private var access: some View {
        VStack(alignment: .leading, spacing: 10) {
            StepTitle("Autorise Temps d'écran.", line: "C'est lui qui compte ton temps et bloque. Rien ne quitte ton iPhone.")
            if requesting {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("iOS ouvre sa fenêtre…").foregroundStyle(.secondary)
                }
                .padding(.top, 8)
                .transition(.opacity)
            }
            if accessDenied {
                Text("Sans cette autorisation, rien ne se bloque.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.blocked)
            }
            Spacer()
        }
    }

    private var apps: some View {
        VStack(alignment: .leading, spacing: 10) {
            StepTitle("Quelles apps te prennent du temps ?", line: "Elles partagent un seul compteur.")
            Spacer()
            if appsChosen && !model.demo {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 18) {
                    ForEach(Array(selection.applicationTokens), id: \.self) { token in
                        ChosenApp { Label(token) }
                    }
                    ForEach(Array(selection.categoryTokens), id: \.self) { token in
                        ChosenApp { Label(token) }
                    }
                }
                Button("Modifier") { showPicker = true }
                    .font(.body.weight(.medium))
                    .frame(maxWidth: .infinity, minHeight: 44)
            } else if appsChosen {
                HStack(spacing: 18) {
                    ForEach(0..<4, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Theme.accent.opacity(0.25 + Double(index) * 0.25))
                            .frame(width: 60, height: 60)
                    }
                }
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
            } else {
                Button {
                    next()
                } label: {
                    VStack(spacing: 10) {
                        Image(systemName: "plus")
                            .font(.title.weight(.semibold))
                        Text("Choisir les apps")
                            .font(.headline)
                    }
                    .foregroundStyle(Theme.accent)
                    .frame(maxWidth: .infinity, minHeight: 160)
                    .background(Theme.accentGround, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Theme.accent.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [7, 6]))
                    }
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    private var minutesStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            StepTitle("Combien par jour ?", line: "Pour l'allonger, il faudra attendre 24 h.")
            Spacer()
            ValueStepper(value: formatMinutes(minutes), lessLabel: "Moins 5 minutes", moreLabel: "Plus 5 minutes") {
                minutes = max(Policy.minutesRange.lowerBound, minutes - 5)
            } more: {
                minutes = min(Policy.minutesRange.upperBound, minutes + 5)
            }
            Spacer()
        }
    }

    private var siteStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            StepTitle("Quel site bloquer ?", line: "Seulement lui, tout le temps, dans tous les navigateurs.")
                .padding(.bottom, 12)
            TextField("youtube.com", text: $site)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .submitLabel(.done)
                .padding(.horizontal, 16)
                .frame(minHeight: 52)
                .background(Theme.field, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityLabel("Site à bloquer")
            if siteInvalid {
                Text("Écris-le comme ça : youtube.com")
                    .font(.footnote)
                    .foregroundStyle(Theme.blocked)
            }
            Spacer()
        }
    }

    private var notifyStep: some View {
        VStack(spacing: 16) {
            Spacer()
            Owl(name: "owl-patient", label: "Le hibou attend, assis sur sa montre", height: 190)
            Text("Je te préviens avant la fin.")
                .font(Theme.heading)
                .multilineTextAlignment(.center)
            Text("À la moitié de ton temps, puis 5 min avant. Même en mode Concentration.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
    }

    private var lockStep: some View {
        VStack(spacing: 16) {
            Spacer()
            Owl(name: "owl-cadenas", label: "Le hibou tient un cadenas", height: 190)
            Text("Verrouille la suppression d'apps.")
                .font(Theme.heading)
                .multilineTextAlignment(.center)
            Text("Sinon, supprimer Time Keeper suffit. Ça vaut pour toutes tes apps.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
    }

    private var ready: some View {
        VStack(spacing: 14) {
            Owl(name: "owl-lit", label: "Le hibou lit un livre", height: 150)
                .padding(.top, 28)
            Text("Ton temps te revient.")
                .font(Theme.heading)
                .multilineTextAlignment(.center)
            VStack(spacing: 0) {
                ForEach(summary) { row in
                    HStack {
                        Text(row.label)
                        Spacer()
                        Text(row.value).font(Theme.value)
                    }
                    .frame(minHeight: 48)
                    .overlay(alignment: .bottom) { Rectangle().fill(Theme.hairline).frame(height: 1) }
                    .accessibilityElement(children: .combine)
                }
            }
            Text("Ton temps d'aujourd'hui compte déjà.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)
        }
    }

    private var summary: [SummaryRow] {
        var rows: [SummaryRow] = []
        if goal != .site { rows.append(SummaryRow(label: limitName, value: formatMinutes(minutes))) }
        if goal == .site, let domain = Rules.normalizeDomain(site) { rows.append(SummaryRow(label: domain, value: "Bloqué")) }
        rows.append(SummaryRow(label: "Remise à zéro", value: dayStart.label))
        if lock { rows.append(SummaryRow(label: "Suppression d'apps", value: "Verrouillée")) }
        return rows
    }

    private var footer: some View {
        VStack(spacing: 4) {
            Button(action: next) {
                Text(cta).frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(ctaDisabled)
            .opacity(step == .apps && !appsChosen ? 0 : 1)
            .sensoryFeedback(.selection, trigger: step)
            if step == .notify {
                Button("Plus tard") { go(1) }
                    .font(.body.weight(.medium))
                    .frame(maxWidth: .infinity, minHeight: 44)
            } else if step == .lock {
                Button("Plus tard") { advance(lock: false) }
                    .font(.body.weight(.medium))
                    .frame(maxWidth: .infinity, minHeight: 44)
            } else {
                Color.clear.frame(height: 44)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }

    private var cta: String {
        switch step {
        case .welcome: "Commencer"
        case .how: "Poser ma limite"
        case .access: requesting ? "Un instant…" : "Autoriser"
                case .notify: "Me prévenir"
        case .site: "Bloquer ce site"
        case .lock: "Verrouiller"
        case .ready: goal == .site ? "Voir mon site bloqué" : "Voir ma limite"
        default: "Continuer"
        }
    }

    private var ctaDisabled: Bool {
        switch step {
        case .site: site.trimmingCharacters(in: .whitespaces).isEmpty
        case .apps: !appsChosen
        case .access: requesting
        default: false
        }
    }

    private func next() {
        switch step {
        case .access:
            requestAccess()
        case .apps where !appsChosen:
            if model.demo { demoPicked = true } else { showPicker = true }
        case .site:
            if Rules.normalizeDomain(site) == nil { siteInvalid = true } else { siteInvalid = false; go(1) }
        case .notify:
            if model.demo { go(1) } else { Reminder.requestPermission { go(1) } }
        case .lock:
            advance(lock: true)
        case .ready:
            model.finishOnboarding()
        default:
            go(1)
        }
    }

    private var accessGranted: Bool { model.demo || auth.authorizationStatus == .approved }

    private func go(_ delta: Int) {
        var index = position + delta
        while flow.indices.contains(index), flow[index] == .access, accessGranted, step != .access {
            index += delta
        }
        guard flow.indices.contains(index) else { return }
        step = flow[index]
    }

    private func requestAccess() {
        if model.demo { go(1); return }
        requesting = true
        Task {
            do {
                try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                accessDenied = false
                requesting = false
                go(1)
            } catch {
                accessDenied = true
                requesting = false
            }
        }
    }

    private func advance(lock: Bool) {
        self.lock = lock
        model.applyOnboarding(rules)
        go(1)
    }

    private var rules: Rules {
        var rules = Rules()
        if goal != .site, appsChosen {
            rules.groups = [LimitGroup(name: limitName, selection: selection, minutes: minutes)]
        }
        if goal == .site, let domain = Rules.normalizeDomain(site) {
            rules.blockedDomains = [domain]
        }
        rules.denyAppRemoval = lock
        rules.dayStart = dayStart
        return rules
    }
}

private struct SummaryRow: Identifiable {
    let label: String
    let value: String
    var id: String { label }
}

private struct Owl: View {
    let name: String
    let label: String
    let height: CGFloat
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(height: height)
            .scaleEffect(shown || reduceMotion ? 1 : 0.6)
            .opacity(shown ? 1 : 0)
            .onAppear {
                withAnimation(reduceMotion ? .easeIn(duration: 0.2) : .spring(response: 0.45, dampingFraction: 0.55)) { shown = true }
            }
            .accessibilityLabel(label)
    }
}

private struct StepTitle: View {
    let title: String
    let line: String?

    init(_ title: String, line: String? = nil) {
        self.title = title
        self.line = line
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Theme.heading)
                .accessibilityAddTraits(.isHeader)
            if let line {
                Text(line)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct ValueStepper: View {
    let value: String
    let lessLabel: String
    let moreLabel: String
    let less: () -> Void
    let more: () -> Void
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 56

    var body: some View {
        HStack(spacing: 20) {
            round("minus", lessLabel, less)
            Text(value)
                .font(.system(size: size, design: .serif).monospacedDigit())
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .contentTransition(.numericText())
                .frame(minWidth: 150)
            round("plus", moreLabel, more)
        }
        .frame(maxWidth: .infinity)
        .sensoryFeedback(.selection, trigger: value)
        .animation(.snappy, value: value)
    }

    private func round(_ symbol: String, _ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .frame(width: 56, height: 56)
                .background(Theme.field, in: Circle())
        }
        .accessibilityLabel(label)
    }
}

private struct ShieldPreview: View {
    var body: some View {
        VStack(spacing: 14) {
            Image("owl-cadenas")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)
            Text("Cette app est bloquée")
                .font(.headline)
            Text("Ta limite du jour est atteinte. Ça se débloque demain, pas avant.")
                .font(.subheadline)
                .foregroundStyle(Theme.nightSecondary)
                .multilineTextAlignment(.center)
            Spacer()
            Text("Fermer")
                .font(.headline)
                .foregroundStyle(Theme.night)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(.top, 40)
        .foregroundStyle(.white)
        .padding(24)
        .frame(width: 280, height: 400)
        .background(Theme.night, in: RoundedRectangle(cornerRadius: 36, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Exemple d'écran de blocage : cette app est bloquée, un seul bouton Fermer.")
    }
}

private struct Choice: View {
    let label: String
    let on: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(label).font(.body.weight(.medium))
                Spacer()
                if on {
                    Image(systemName: "checkmark").font(.body.weight(.semibold)).foregroundStyle(Theme.accent)
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
            .background(on ? Theme.accentGround : Color.clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(on ? Theme.accent : Theme.hairline, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: on)
    }
}

private struct ChosenApp<Content: View>: View {
    @ViewBuilder let label: () -> Content

    var body: some View {
        VStack(spacing: 6) {
            label().labelStyle(.iconOnly).scaleEffect(2).frame(height: 52)
            label().labelStyle(.titleOnly).font(.caption).lineLimit(1)
        }
    }
}

private struct CountUp: View {
    let target: Int
    @State private var value = 0
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 88
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text("\(value)")
            .font(.system(size: size, weight: .semibold, design: .serif).monospacedDigit())
            .foregroundStyle(Theme.accent)
            .contentTransition(.numericText(value: Double(value)))
            .sensoryFeedback(.impact(weight: .medium), trigger: value == target)
            .task {
                if reduceMotion { value = target; return }
                try? await Task.sleep(for: .milliseconds(300))
                withAnimation(.smooth(duration: 1.2)) { value = target }
            }
    }
}
