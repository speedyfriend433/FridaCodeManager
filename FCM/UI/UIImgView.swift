 /* 
 UIImgView.swift 

 Copyright (C) 2023, 2024 SparkleChan and SeanIsTethered 
 Copyright (C) 2024 fridakitten 

 This file is part of FridaCodeManager. 

 FridaCodeManager is free software: you can redistribute it and/or modify 
 it under the terms of the GNU General Public License as published by 
 the Free Software Foundation, either version 3 of the License, or 
 (at your option) any later version. 

 FridaCodeManager is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of 
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the 
 GNU General Public License for more details. 

 You should have received a copy of the GNU General Public License 
 along with FridaCodeManager. If not, see <https://www.gnu.org/licenses/>. 

  ______    _     _         _____        __ _                           ______                    _       _   _
 |  ___|  (_)   | |       /  ___|      / _| |                          |  ___|                  | |     | | (_)
 | |_ _ __ _  __| | __ _  \ `--.  ___ | |_| |___      ____ _ _ __ ___  | |_ ___  _   _ _ __   __| | __ _| |_ _  ___  _ __
 |  _| '__| |/ _` |/ _` |  `--. \/ _ \|  _| __\ \ /\ / / _` | '__/ _ \ |  _/ _ \| | | | '_ \ / _` |/ _` | __| |/ _ \| '_ \
 | | | |  | | (_| | (_| | /\__/ / (_) | | | |_ \ V  V / (_| | | |  __/ | || (_) | |_| | | | | (_| | (_| | |_| | (_) | | | |
 \_| |_|  |_|\__,_|\__,_| \____/ \___/|_|  \__| \_/\_/ \__,_|_|  \___| \_| \___/ \__,_|_| |_|\__,_|\__,_|\__|_|\___/|_| |_|
 Founded by. Sean Boleslawski, Benjamin Hornbeck and Lucienne Salim in 2023
 */ 

import SwiftUI
import Combine
import UIKit
import Foundation

struct PubImg: View {
    @State var projpath: String
    @State var selectedImage: UIImage?

    var body: some View {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .cornerRadius(10)
            } else {
                Rectangle()
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.primary, lineWidth: 2)
                    )
            }
            Spacer().frame(width: 0, height:0)
            .onAppear {
                if selectedImage == nil {
                    if FileManager.default.fileExists(atPath: "\(projpath)/Resources/AppIcon.png") {
                        selectedImage = loadImage(fromPath: "\(projpath)/Resources/AppIcon.png")
                    } else if FileManager.default.fileExists(atPath: "\(Bundle.main.bundlePath)/default.png") {
                        selectedImage = loadImage(fromPath: "\(Bundle.main.bundlePath)/default.png")
                    }
                }
        }
    }
}

struct AsyncImageLoaderView: View {
    @StateObject private var imageLoader = ImageLoader()
    private let urlString: String
    private let width: CGFloat?
    private let height: CGFloat?

    init(urlString: String, width: CGFloat? = nil, height: CGFloat? = nil) {
        self.urlString = urlString
        self.width = width
        self.height = height
    }

    private var url: URL? {
        URL(string: urlString)
    }

    var body: some View {
        if let uiImage = imageLoader.image {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: width, height: height)
                .clipShape(Circle())
        } else {
            ProgressView()
                .aspectRatio(contentMode: .fit)
                .frame(width: width, height: height)
                .onAppear {
                    if let url = url {
                        imageLoader.loadImage(from: url)
                    }
                }
        }
    }
}

class ImageLoader: ObservableObject {
    @Published var image: UIImage?

    private var cancellable: AnyCancellable?
    private let maxRetries = 3
    private let retryDelay = 2.0

    func loadImage(from url: URL) {
        cancellable?.cancel()

        cancellable = URLSession.shared.dataTaskPublisher(for: url)
            .tryMap { (data, response) in
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }
                return data
            }
            .compactMap { UIImage(data: $0) }
            .receive(on: DispatchQueue.main)
            .retry(maxRetries)
            .catch { [weak self] error -> AnyPublisher<UIImage?, Never> in
                print("Failed to load image: \(error.localizedDescription)")
                return Just(nil).delay(for: .seconds(self?.retryDelay ?? 2.0), scheduler: RunLoop.main).eraseToAnyPublisher()
            }
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] loadedImage in
                self?.image = loadedImage
            })
    }

    deinit {
        cancellable?.cancel()
    }
}
