//
//  BottomBar.swift
//  RSSBud
//
//  Created by Cay Zhang on 2021/6/17.
//

import SwiftUI
import Combine
import LinkPresentation

struct BottomBar: View {
    @ObservedObject var viewModel: Self.ViewModel
    
    var body: some View {
        let url = viewModel.linkURL ?? URLComponents()
        ZStack {
            viewModel.linkImage?
                .resizable()
                .aspectRatio(1, contentMode: .fill)
                .opacity((!viewModel.isEditing && viewModel.progress == 1.0) ? 0.5 : 0.0)
                .allowsHitTesting(false)
            
            Rectangle().fill(.thinMaterial).transition(.identity)
            
            AutoAdvancingProgressView(viewModel: viewModel.progressViewModel)
                .progressViewStyle(BarProgressViewStyle())
                .tint(!viewModel.isFailed ? nil : .red)
                .opacity((viewModel.progress != 1.0) ? 0.1 : 0.0)
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    linkTitleView
                        .font(.system(size: 15, weight: .semibold, design: .default))
                        .transition(.offset(y: -25).combined(with: .opacity))
                    
                    linkURLView(url: url)
                        .environment(\.backgroundMaterial, .thin)
                }
                Spacer()
                if !viewModel.isEditing && viewModel.linkIconSize == .large {
                    viewModel.linkIcon?
                        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                        .transition(.offset(x: 25).combined(with: .opacity))
                }
            }.padding(16)
            .font(Font.body.weight(.semibold))
            .layoutPriority(1)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contextMenu(menuItems: linkViewContextMenuItems)
        }.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.15), radius: 12, y: 3)
        .transition(.offset(y: 50).combined(with: .scale(scale: 0.5)).combined(with: .opacity))
        .gesture(
            DragGesture(minimumDistance: 5)
                .onChanged { value in
                    if value.predictedEndTranslation.height < -20 && !viewModel.isEditing {
                        withAnimation {
                            viewModel.isEditing = true
                        }
                    } else if value.predictedEndTranslation.height > 20 && viewModel.isEditing {
                        withAnimation {
                            viewModel.isEditing = false
                        }
                    }
                }
        )
        .animation(Self.transitionAnimation, value: viewModel.linkTitle)
        .animation(Self.transitionAnimation, value: viewModel.isEditing)
    }
    
    @ViewBuilder func linkViewContextMenuItems() -> some View {
        Button {
            viewModel.linkURL?.url.map { UIPasteboard.general.url = $0 }
        } label: {
            Label("Copy Link", systemImage: "doc.on.doc.fill")
        }
        
        Button(action: viewModel.dismiss) {
            Label("Dismiss Current Analysis", systemImage: "clear.fill")
        }
    }
    
    @ViewBuilder var linkTitleView: some View {
        if !viewModel.isEditing, let title = viewModel.linkTitle {
            if let icon = viewModel.linkIcon, viewModel.linkIconSize == .small {
                Label { Text(title).lineLimit(1) } icon: { icon }
            } else {
                Text(title).lineLimit(2)
            }
        }
    }
    
    @ViewBuilder func linkURLView(url: URLComponents) -> some View {
        ZStack(alignment: .leading) {
            ValidatedTextField("Bottom Bar Start Prompt", text: $viewModel.editingText) { $0.isEmpty || URLComponents(string: $0)?.host != nil }
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .animatableFont(size: (viewModel.linkTitle != nil && !viewModel.isEditing) ? 13 : 15, weight: .semibold)
                .opacity(viewModel.isEditing ? 1 : 0)
                .offset(x: viewModel.isEditing ? 0 : -30)
                .onSubmit {
                    URLComponents(autoPercentEncoding: viewModel.editingText)
                        .map(viewModel.onSubmit)
                }
            Text((viewModel.linkTitle != nil) ? conciseRepresentation(of: url) : detailedRepresentation(of: url))
                .foregroundStyle(.secondary)
                .animatableFont(size: (viewModel.linkTitle != nil && !viewModel.isEditing) ? 13 : 15, weight: (viewModel.linkTitle != nil && !viewModel.isEditing) ? .regular : .semibold)
                .opacity(!viewModel.isEditing ? 1 : 0)
                .offset(x: viewModel.isEditing ? 30 : 0)
        }
    }
}

extension BottomBar {
    class ViewModel: ObservableObject {
        @Published var linkURL: URLComponents?
        @Published var linkTitle: String?
        @Published var linkIcon: Image?
        @Published var linkImage: Image?
        @Published var linkIconSize: LinkIconSize = .large
        
        @Published var isFailed: Bool = false
        @Published var _isEditing: Bool = true
        @Published var editingText: String = ""
        
        @Published var progress: Double = 1.0
        let progressViewModel = AutoAdvancingProgressView.ViewModel()
        
        var dismiss: () -> Void = { }
        var onSubmit: (URLComponents) -> Void = { _ in }
        
        var cancelBag = Set<AnyCancellable>()
        
        init() {
            $progress
                .assign(to: \.progress, on: progressViewModel)
                .store(in: &cancelBag)
        }
        
        var isEditing: Bool {
            get { _isEditing }
            set {
                _isEditing = newValue
                if newValue {
                    editingText = linkURL?.string ?? ""
                }
            }
        }
    }
}

extension BottomBar {
    enum LinkIconSize {
        case small, large
    }
    
    func conciseRepresentation(of url: URLComponents) -> AttributedString {
        AttributedString(url.host ?? url.string ?? "")
    }
    
    func detailedRepresentation(of url: URLComponents) -> AttributedString {
        guard let rangeOfHost = url.rangeOfHost,
              let startingIndexOfPath = url.rangeOfPath?.lowerBound,
              let hostString = url.string?[rangeOfHost],
              let afterHostString = url.string?[startingIndexOfPath...]
        else {
            return AttributedString(url.string ?? "")
        }
        var host = AttributedString(hostString)
        host.foregroundColor = Color.primary
        let afterHost = AttributedString(afterHostString)
        return host + afterHost
    }
}

extension BottomBar {
    static var transitionAnimation: Animation { Animation.interpolatingSpring(mass: 3, stiffness: 1000, damping: 500, initialVelocity: 0) }
    static var contentTransition: AnyTransition {
        AnyTransition.offset(y: 25).combined(with: AnyTransition.opacity)
    }
}

struct BottomBar_Previews: PreviewProvider {
    static var contentViewModels = [ContentView.ViewModel]()
    
    static func bottomBar(for url: URLComponents) -> BottomBar {
        let model = ContentView.ViewModel()
        contentViewModels.append(model)
        model.originalURL = url
        return BottomBar(viewModel: model.bottomBarViewModel)
    }
    
    static var previews: some View {
        Group {
            bottomBar(for: "https://space.bilibili.com/17404347")
            bottomBar(for: "https://www.youtube.com/watch?v=7A5-eRfDQ0M")
        }
    }
}
