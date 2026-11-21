import SwiftUI
import FamilyControls

enum OnboardingStep: Int, CaseIterable {
    case welcome, aha, goals, access, apps, minutes, notify, site, lock, ready
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
    @State private var found = false
    @State private var tries = 0
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
        case .aha: aha
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
            Owl(name: "owl-montre", label: "Le hibou de Time Keeper serre sa montre", height: 190)
            Text("Ta limite va enfin tenir.")
                .font(Theme.title)
                .multilineTextAlignment(.center)
            Spacer()
        }
    }

    private var aha: some View {
        VStack(spacing: 20) {
            if found {
                Spacer()
                Owl(name: "owl-non", label: "Le hibou fait non de la tête", height: 200)
                Text("Il n'y en a pas.")
                    .font(Theme.title)
                    .multilineTextAlignment(.center)
                Text("Ta limite tient pour toi.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Spacer()
            } else {
                Text("Trouve le bouton Ignorer.")
                    .font(Theme.heading)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                ShieldPreview(tries: tries) {
                    tries += 1
                } onClose: {
                    found = true
                }
                .sensoryFeedback(.impact(weight: .light), trigger: tries)
                Spacer(minLength: 0)
            }
        }
        .sensoryFeedback(trigger: found) { _, now in now ? .success : nil }
    }

    private var goalsStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            StepTitle("Qu'est-ce qui te prend le plus de temps ?")
                .padding(.bottom, 12)
            ForEach(OnboardingGoal.allCases) { option in
                let on = goal == option
                Button {
                    goal = option
                } label: {
                    HStack {
                        Text(option.label).font(.body.weight(.medium))
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
    }

    private var access: some View {
        VStack(alignment: .leading, spacing: 10) {
            StepTitle("Autorise Temps d'écran.", line: "Il bloque, sans son bouton Ignorer. Rien ne quitte ton iPhone.")
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
            StepTitle("Quelles apps limiter ?", line: "Un seul compteur pour toutes.")
            Spacer()
            if appsChosen && !model.demo {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 18), count: 4), spacing: 18) {
                    ForEach(Array(selection.applicationTokens), id: \.self) { token in
                        Label(token).labelStyle(.iconOnly).scaleEffect(2.2).frame(height: 60)
                    }
                    ForEach(Array(selection.categoryTokens), id: \.self) { token in
                        Label(token).labelStyle(.iconOnly).scaleEffect(2.2).frame(height: 60)
                    }
                }
            } else {
                HStack(spacing: 18) {
                    ForEach(0..<4, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(appsChosen ? Theme.accent.opacity(0.25 + Double(index) * 0.25) : Color.clear)
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(appsChosen ? Color.clear : Theme.hairline, style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                            }
                            .frame(width: 60, height: 60)
                    }
                }
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
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
            Owl(name: "owl-montre", label: "Le hibou serre sa montre", height: 190)
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
                .padding(.top, 8)
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
        .opacity(step == .aha && !found ? 0 : 1)
        .allowsHitTesting(!(step == .aha && !found))
        .animation(.easeIn(duration: 0.3).delay(found ? 1 : 0), value: found)
    }

    private var cta: String {
        switch step {
        case .welcome: "Voir comment"
        case .aha: "Poser ma limite"
        case .access: "Autoriser"
        case .apps: appsChosen ? "Continuer" : "Choisir les apps"
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
        if flow[index] == .aha { found = false; tries = 0 }
        step = flow[index]
    }

    private func requestAccess() {
        if model.demo { go(1); return }
        Task {
            do {
                try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                accessDenied = false
                go(1)
            } catch {
                accessDenied = true
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
    let tries: Int
    let onMiss: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Button(action: onMiss) {
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
                }
                .padding(.top, 40)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Écran de blocage")
            Button(action: onClose) {
                Text("Fermer")
                    .font(.headline)
                    .foregroundStyle(Theme.night)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.white)
        .padding(24)
        .frame(width: 300, height: 420)
        .background(Theme.night, in: RoundedRectangle(cornerRadius: 36, style: .continuous))
        .offset(x: tries % 2 == 1 ? -6 : 0)
        .animation(.spring(response: 0.2, dampingFraction: 0.3), value: tries)
    }
}
