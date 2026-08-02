import SwiftUI

@MainActor
public struct SettingsView: View {
    @AppStorage("speech_language") private var selectedLanguage: String = "tr-TR"
    @AppStorage("auto_ai_summary") private var autoAiSummary: Bool = true
    @AppStorage("haptics_enabled") private var hapticsEnabled: Bool = true
    @AppStorage("user_profile_name") private var userName: String = "Ahmet"
    @AppStorage("notifications_enabled") private var notificationsEnabled: Bool = true
    @AppStorage("audio_quality") private var audioQuality: String = "HQ"
    @AppStorage("auto_delete_period") private var autoDeletePeriod: String = "Never"
    
    @State private var showPreferencesSheet: Bool = false
    @State private var showChangePasswordSheet: Bool = false
    @State private var showLogoutAlert: Bool = false
    
    @State private var oldPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var passwordChangeSuccess: Bool = false
    
    private let languages: [(code: String, name: String, flag: String)] = [
        ("tr-TR", "Türkçe", "🇹🇷"),
        ("en-US", "İngilizce", "🇺🇸")
    ]
    
    public init() {}
    
    private func languageName(for code: String) -> String {
        switch code {
        case "tr-TR": return "Türkçe"
        case "en-US": return "İngilizce"
        default: return "Türkçe"
        }
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                // Background Gradient & Ambient Glow Blobs
                VoiceTheme.backgroundGradient.ignoresSafeArea()
                
                ZStack {
                    Circle()
                        .fill(VoiceTheme.primaryGlow.opacity(0.16))
                        .frame(width: 320, height: 320)
                        .blur(radius: 65)
                        .offset(x: 100, y: -140)
                    
                    Circle()
                        .fill(VoiceTheme.accentCyan.opacity(0.14))
                        .frame(width: 260, height: 260)
                        .blur(radius: 55)
                        .offset(x: -120, y: 160)
                }
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Personal User Profile Hero Card
                        VStack(spacing: 14) {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(VoiceTheme.recordButtonGradient)
                                        .frame(width: 56, height: 56)
                                        .shadow(color: VoiceTheme.primaryGlow.opacity(0.5), radius: 10, x: 0, y: 4)
                                    
                                    Image(systemName: "person.crop.circle.fill")
                                        .font(.system(size: 30))
                                        .foregroundColor(.white)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text("Hoş Geldin,")
                                            .font(.system(size: 18, weight: .bold, design: .rounded))
                                            .foregroundColor(VoiceTheme.textPrimary)
                                        
                                        TextField("İsminiz", text: $userName)
                                            .font(.system(size: 18, weight: .bold, design: .rounded))
                                            .foregroundColor(VoiceTheme.accentCyan)
                                            .textFieldStyle(.plain)
                                        
                                        Text("👋")
                                            .font(.system(size: 18))
                                    }
                                    
                                    Text("Kişisel Sesli Asistanınız")
                                        .font(.caption)
                                        .foregroundColor(VoiceTheme.textSecondary)
                                }
                                
                                Spacer()
                            }
                            
                            Divider().background(VoiceTheme.bgCardBorder.opacity(0.6))
                            
                            // User Stat Row
                            HStack(spacing: 12) {
                                statItem(
                                    title: "Yapay Zeka",
                                    value: "Aktif ⚡",
                                    icon: "sparkles",
                                    color: VoiceTheme.accentPink
                                )
                                
                                Divider().frame(height: 28).background(VoiceTheme.bgCardBorder)
                                
                                statItem(
                                    title: "Konuşma Dili",
                                    value: languageName(for: selectedLanguage),
                                    icon: "globe",
                                    color: VoiceTheme.accentCyan
                                )
                                
                                Divider().frame(height: 28).background(VoiceTheme.bgCardBorder)
                                
                                statItem(
                                    title: "Hesap",
                                    value: "Korumalı 🔒",
                                    icon: "shield.checkmark.fill",
                                    color: Color.green
                                )
                            }
                        }
                        .glassCardStyle()
                        
                        // Speech & Recording Preferences Card
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(VoiceTheme.accentCyan)
                                Text("Sesli Not & Dikte Tercihleri")
                                    .font(.headline.bold())
                                    .foregroundColor(VoiceTheme.textPrimary)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Konuşma Dili")
                                    .font(.caption.bold())
                                    .foregroundColor(VoiceTheme.textSecondary)
                                
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                    ForEach(languages, id: \.code) { lang in
                                        Button(action: { selectedLanguage = lang.code }) {
                                            HStack(spacing: 8) {
                                                Text(lang.flag)
                                                    .font(.title3)
                                                Text(lang.name)
                                                    .font(.subheadline.bold())
                                                    .foregroundColor(selectedLanguage == lang.code ? .white : VoiceTheme.textSecondary)
                                                Spacer()
                                                if selectedLanguage == lang.code {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundColor(VoiceTheme.accentCyan)
                                                }
                                            }
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 12)
                                            .background(selectedLanguage == lang.code ? VoiceTheme.primaryGlow.opacity(0.8) : VoiceTheme.bgCard)
                                            .cornerRadius(14)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 14)
                                                    .stroke(selectedLanguage == lang.code ? VoiceTheme.accentCyan : VoiceTheme.bgCardBorder.opacity(0.5), lineWidth: 1)
                                            )
                                        }
                                    }
                                }
                            }
                            
                            Divider().background(VoiceTheme.bgCardBorder.opacity(0.5))
                            
                            Toggle(isOn: $autoAiSummary) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Otomatik Yapay Zeka Özeti")
                                        .font(.subheadline.bold())
                                        .foregroundColor(VoiceTheme.textPrimary)
                                    Text("Kayıt tamamlandığında otomatik özet hazırlar")
                                        .font(.caption)
                                        .foregroundColor(VoiceTheme.textSecondary)
                                }
                            }
                            .tint(VoiceTheme.accentCyan)
                            
                            Divider().background(VoiceTheme.bgCardBorder.opacity(0.5))
                            
                            Toggle(isOn: $hapticsEnabled) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Dokunma Titreşimi")
                                        .font(.subheadline.bold())
                                        .foregroundColor(VoiceTheme.textPrimary)
                                    Text("Buton etkileşimlerinde hafif geri bildirim verir")
                                        .font(.caption)
                                        .foregroundColor(VoiceTheme.textSecondary)
                                }
                            }
                            .tint(VoiceTheme.primaryGlow)
                        }
                        .glassCardStyle()
                        
                        // Account & Security Card with Tercihler, Şifre Değiştir, Çıkış Yap
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(VoiceTheme.accentPink)
                                Text("Hesap & Tercihler")
                                    .font(.headline.bold())
                                    .foregroundColor(VoiceTheme.textPrimary)
                            }
                            
                            // Tercihler Button
                            Button(action: { showPreferencesSheet = true }) {
                                HStack {
                                    HStack(spacing: 10) {
                                        Image(systemName: "slider.horizontal.3")
                                            .foregroundColor(VoiceTheme.accentCyan)
                                        Text("Tercihler")
                                            .font(.subheadline.bold())
                                            .foregroundColor(VoiceTheme.textPrimary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(VoiceTheme.textSecondary)
                                }
                                .padding()
                                .background(VoiceTheme.bgCard)
                                .cornerRadius(14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(VoiceTheme.bgCardBorder.opacity(0.6), lineWidth: 1)
                                )
                            }
                            
                            // Şifre Değiştir Button
                            Button(action: { showChangePasswordSheet = true }) {
                                HStack {
                                    HStack(spacing: 10) {
                                        Image(systemName: "key.fill")
                                            .foregroundColor(VoiceTheme.primaryGlow)
                                        Text("Şifre Değiştir")
                                            .font(.subheadline.bold())
                                            .foregroundColor(VoiceTheme.textPrimary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(VoiceTheme.textSecondary)
                                }
                                .padding()
                                .background(VoiceTheme.bgCard)
                                .cornerRadius(14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(VoiceTheme.bgCardBorder.opacity(0.6), lineWidth: 1)
                                )
                            }
                            
                            // Çıkış Yap Button
                            Button(action: { showLogoutAlert = true }) {
                                HStack {
                                    HStack(spacing: 10) {
                                        Image(systemName: "rectangle.portrait.and.arrow.right.fill")
                                            .foregroundColor(Color.red)
                                        Text("Çıkış Yap")
                                            .font(.subheadline.bold())
                                            .foregroundColor(Color.red)
                                    }
                                    Spacer()
                                }
                                .padding()
                                .background(Color.red.opacity(0.12))
                                .cornerRadius(14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                )
                            }
                        }
                        .glassCardStyle()
                    }
                    .padding()
                }
            }
            .navigationTitle("")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .sheet(isPresented: $showPreferencesSheet) {
                preferencesSheet
            }
            .sheet(isPresented: $showChangePasswordSheet) {
                changePasswordSheet
            }
            .alert("Çıkış Yap", isPresented: $showLogoutAlert) {
                Button("İptal", role: .cancel) {}
                Button("Çıkış Yap", role: .destructive) {
                    print("Kullanıcı çıkış yaptı.")
                }
            } message: {
                Text("Hesabınızdan çıkış yapmak istediğinize emin misiniz?")
            }
        }
    }
    
    private var preferencesSheet: some View {
        ZStack {
            VoiceTheme.bgDark.ignoresSafeArea()
            
            VStack(spacing: 20) {
                HStack {
                    Text("Uygulama Tercihleri")
                        .font(.title2.bold())
                        .foregroundColor(VoiceTheme.textPrimary)
                    Spacer()
                    Button(action: { showPreferencesSheet = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(VoiceTheme.textSecondary)
                    }
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    Toggle(isOn: $notificationsEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Bildirimler")
                                .font(.subheadline.bold())
                                .foregroundColor(VoiceTheme.textPrimary)
                            Text("Kayıt hatırlatıcıları ve uygulama güncellemeleri")
                                .font(.caption)
                                .foregroundColor(VoiceTheme.textSecondary)
                        }
                    }
                    .tint(VoiceTheme.accentCyan)
                    
                    Divider().background(VoiceTheme.bgCardBorder.opacity(0.5))
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ses Kayıt Kalitesi")
                            .font(.subheadline.bold())
                            .foregroundColor(VoiceTheme.textPrimary)
                        
                        Picker("Ses Kalitesi", selection: $audioQuality) {
                            Text("Yüksek Kalite (HQ)").tag("HQ")
                            Text("Standart Kalite").tag("Standard")
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    Divider().background(VoiceTheme.bgCardBorder.opacity(0.5))
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Eski Kayıtları Otomatik Temizle")
                            .font(.subheadline.bold())
                            .foregroundColor(VoiceTheme.textPrimary)
                        
                        Picker("Otomatik Sil", selection: $autoDeletePeriod) {
                            Text("Asla").tag("Never")
                            Text("30 Gün").tag("30Days")
                            Text("60 Gün").tag("60Days")
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .glassCardStyle()
                
                Button(action: { showPreferencesSheet = false }) {
                    Text("Tercihleri Kaydet")
                        .font(.headline.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(VoiceTheme.recordButtonGradient)
                        .cornerRadius(16)
                        .shadow(color: VoiceTheme.primaryGlow.opacity(0.4), radius: 8, x: 0, y: 3)
                }
                
                Spacer()
            }
            .padding(24)
        }
    }
    
    private var changePasswordSheet: some View {
        ZStack {
            VoiceTheme.bgDark.ignoresSafeArea()
            
            VStack(spacing: 20) {
                HStack {
                    Text("Şifre Değiştir")
                        .font(.title2.bold())
                        .foregroundColor(VoiceTheme.textPrimary)
                    Spacer()
                    Button(action: { showChangePasswordSheet = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(VoiceTheme.textSecondary)
                    }
                }
                
                if passwordChangeSuccess {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color.green)
                        Text("Şifreniz başarıyla güncellendi!")
                            .font(.subheadline.bold())
                            .foregroundColor(Color.green)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green.opacity(0.15))
                    .cornerRadius(14)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Mevcut Şifre")
                        .font(.caption.bold())
                        .foregroundColor(VoiceTheme.textSecondary)
                    SecureField("Mevcut şifrenizi girin...", text: $oldPassword)
                        .padding()
                        .background(VoiceTheme.bgCard)
                        .cornerRadius(14)
                        .foregroundColor(.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(VoiceTheme.bgCardBorder, lineWidth: 1)
                        )
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Yeni Şifre")
                        .font(.caption.bold())
                        .foregroundColor(VoiceTheme.textSecondary)
                    SecureField("Yeni şifrenizi girin...", text: $newPassword)
                        .padding()
                        .background(VoiceTheme.bgCard)
                        .cornerRadius(14)
                        .foregroundColor(.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(VoiceTheme.bgCardBorder, lineWidth: 1)
                        )
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Yeni Şifre (Tekrar)")
                        .font(.caption.bold())
                        .foregroundColor(VoiceTheme.textSecondary)
                    SecureField("Yeni şifrenizi tekrar girin...", text: $confirmPassword)
                        .padding()
                        .background(VoiceTheme.bgCard)
                        .cornerRadius(14)
                        .foregroundColor(.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(VoiceTheme.bgCardBorder, lineWidth: 1)
                        )
                }
                
                Button(action: handlePasswordUpdate) {
                    Text("Şifreyi Güncelle")
                        .font(.headline.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(VoiceTheme.recordButtonGradient)
                        .cornerRadius(16)
                        .shadow(color: VoiceTheme.primaryGlow.opacity(0.5), radius: 10, x: 0, y: 4)
                }
                
                Spacer()
            }
            .padding(24)
        }
    }
    
    private func handlePasswordUpdate() {
        passwordChangeSuccess = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            passwordChangeSuccess = false
            showChangePasswordSheet = false
            oldPassword = ""
            newPassword = ""
            confirmPassword = ""
        }
    }
    
    private func statItem(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption2)
                    .foregroundColor(VoiceTheme.textSecondary)
            }
            Text(value)
                .font(.caption.bold())
                .foregroundColor(VoiceTheme.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }
}
