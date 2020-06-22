//
//  ContentView.swift
//  Pomosh
//
//  Created by Steven J. Selcuk on 2.06.2020.
//  Copyright © 2020 Steven J. Selcuk. All rights reserved.
//

import SwiftUI
import UserNotifications

let settings = UserDefaults.standard

struct ContentView: View {
    
    // MARK: - Properties
    @State var showingSettings = false
    @ObservedObject var ThePomoshTimer = PomoshTimer()
    var isIpad = UIDevice.current.model.hasPrefix("iPad")
    // @State private var startUp = LaunchAtLogin.isEnabled
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    let notificationCenter = UNUserNotificationCenter.current()
    
    // MARK: - InDaClub
    init() {
        if self.ThePomoshTimer.showNotifications {
            notificationCenter.requestAuthorization(options: [.alert, .badge, .sound]) { (granted, error) in
                if granted {
                    settings.set(true, forKey: "didNotificationsAllowed")
                } else {
                    settings.set(false, forKey: "didNotificationsAllowed")
                }
            }
        }
    }
    // MARK: - Main Component
    var body: some View {
        NavigationView {
            VStack(alignment: .center) {
                TimerRing(color1: #colorLiteral(red: 0.2588235438, green: 0.7568627596, blue: 0.9686274529, alpha: 1), color2: #colorLiteral(red: 0.3647058904, green: 0.06666667014, blue: 0.9686274529, alpha: 1), width: isIpad ? 600 : 300, height: isIpad ? 600 : 300, percent: CGFloat(((Float(ThePomoshTimer.fulltime) - Float(ThePomoshTimer.timeRemaining))/Float(ThePomoshTimer.fulltime)) * 100), Timer: ThePomoshTimer)
                    .padding()
                    .scaledToFit()
                    .frame(maxWidth: 1200, maxHeight: 1200, alignment: .center)
            }
            .navigationBarItems(
                trailing:
                Button(action: {
                    self.showingSettings.toggle()
                }) {
                    HStack {
                        Image("Settings")
                            .antialiased(/*@START_MENU_TOKEN@*/true/*@END_MENU_TOKEN@*/)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 28, maxHeight: 28, alignment: .center)
                    }
                    
                }
                .buttonStyle(PomoshButtonStyle())
            )
                .sheet(isPresented: $showingSettings) {
                    VStack(alignment: .leading, spacing: 15.0) {
                        Spacer()
                        Text("Preferences")
                            .foregroundColor(Color("Text"))
                            .font(.custom("Silka Bold", size: 22))
                        
                        Divider()
                            .padding(.bottom, 10.0)
                        
                        VStack(alignment: .leading, spacing: 30.0) {
                            
                            VStack(alignment: .leading)  {
                                
                                Text("Working Time:  \(self.ThePomoshTimer.fulltime / 60) minute")
                                    .foregroundColor(Color("Text"))
                                    .font(.custom("Silka Regular", size: 14))
                                
                                
                                Slider(value: Binding(
                                    get: {
                                        Double(UserDefaults.standard.integer(forKey: "time"))
                                },
                                    set: {(newValue) in
                                        settings.set(newValue, forKey: "time")
                                        self.ThePomoshTimer.fulltime = Int(newValue)
                                }
                                ),in: 1200...3600, step: 300)
                            }
                            
                            
                            VStack(alignment: .leading)  {
                                Text("Break Time:  \(self.ThePomoshTimer.fullBreakTime / 60) minute")
                                    .foregroundColor(Color("Text"))
                                    .font(.custom("Silka Regular", size: 14))
                                
                                
                                Slider(value: Binding(
                                    get: {
                                        Double(self.ThePomoshTimer.fullBreakTime)
                                },
                                    set: {(newValue) in
                                        settings.set(newValue, forKey: "fullBreakTime")
                                        self.ThePomoshTimer.fullBreakTime = Int(newValue)
                                }
                                ) ,in: 300...600, step: 60)
                            }
                            
                            
                            VStack(alignment: .leading)  {
                                Text("Total cycles in a session")
                                    .foregroundColor(Color("Text"))
                                    .font(.custom("Silka Regular", size: 14))
                                    .padding(.bottom, 10.0)
                                HStack {
                                    
                                    ForEach(0..<self.ThePomoshTimer.fullround, id: \.self) { index in
                                        
                                        Text("🔥")
                                        
                                    }
                                }
                                Slider(value: Binding(
                                    get: {
                                        Double(self.ThePomoshTimer.fullround)
                                        
                                },
                                    set: {(newValue) in
                                        
                                        settings.set(newValue, forKey: "fullround")
                                        self.ThePomoshTimer.fullround = Int(newValue)
                                        
                                }
                                ),in: 1...12)
                            }
                            
                            
                            
                            VStack {
                                Toggle(isOn: self.$ThePomoshTimer.playSound) {
                                    Text("Sound effects")
                                        .foregroundColor(Color("Text"))
                                        .font(.custom("Silka Regular", size: 14))
                                }.padding(.vertical, 5.0)
                                
                                Toggle(isOn: self.$ThePomoshTimer.showNotifications) {
                                    Text("Show Notifications")
                                        .foregroundColor(Color("Text"))
                                        .font(.custom("Silka Regular", size: 14))
                                }
                                .padding(.vertical, 5.0)
                                
                            }
                            
                            Spacer()
                            
                            
                            
                            
                        }
                    }.padding(.horizontal, 30.0)
                    
                    
            }
                
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .center)
            .background(Color("Background"))
            .edgesIgnoringSafeArea(.all)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                self.ThePomoshTimer.isActive = false
                
                if(self.ThePomoshTimer.showNotifications) {
                    //     self.scheduleAlarmNotification(sh: 30)
                }
                
                
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                
                self.ThePomoshTimer.isActive = true
            }
            .onReceive(timer) { time in
                guard self.ThePomoshTimer.isActive else { return }
                
                
                if self.ThePomoshTimer.timeRemaining > 0 {
                    
                    self.ThePomoshTimer.timeRemaining -= 1
                }
                
                if self.ThePomoshTimer.timeRemaining == 1 && self.ThePomoshTimer.round > 0 {
                    
                    if self.ThePomoshTimer.playSound {
                        self.ThePomoshTimer.endSound()
                    }
                    self.ThePomoshTimer.isBreakActive.toggle()
                    
                    if self.ThePomoshTimer.isBreakActive == true {
                        if self.ThePomoshTimer.round == 1 {
                            self.ThePomoshTimer.timeRemaining = 0
                            self.ThePomoshTimer.isBreakActive = false
                        } else {
                            self.ThePomoshTimer.timeRemaining = UserDefaults.standard.optionalInt(forKey: "fullBreakTime") ?? 600
                            self.ThePomoshTimer.fulltime = UserDefaults.standard.optionalInt(forKey: "fullBreakTime") ?? 600
                        }
                        
                        self.ThePomoshTimer.round -= 1
                    } else {
                        self.ThePomoshTimer.fulltime = UserDefaults.standard.optionalInt(forKey: "time") ?? 1200
                        self.ThePomoshTimer.timeRemaining = UserDefaults.standard.optionalInt(forKey: "time") ?? 1200
                    }
                    
                } else if self.ThePomoshTimer.timeRemaining == 0 {
                    self.ThePomoshTimer.isActive = false
                }
                
            }
            
        }
        .navigationViewStyle(StackNavigationViewStyle())
        
    }
    
    // MARK: - Local Notifications
    
    func scheduleAlarmNotification(sh: TimeInterval) {
        let content = UNMutableNotificationContent()
        var bodyString: String  {
            var string = ""
            if self.ThePomoshTimer.isBreakActive == true {
                string = "Now, It's working time 🔥"
            } else {
                string = "It's break time ☕️"
            }
            return string
        }
        content.title = "Time is up 🙌"
        content.body = bodyString
        content.badge = 1
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: sh, repeats: false)
        let identifier = "localNotification"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        notificationCenter.getNotificationSettings { (settings) in
            if settings.authorizationStatus == .authorized {
                self.notificationCenter.add(request) { (error) in
                    if let error = error {
                        print("Error: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
}


