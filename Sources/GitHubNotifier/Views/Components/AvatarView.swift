import Kingfisher
import SwiftUI

struct AvatarView: View {
    let url: URL?
    let size: CGFloat

    init(url: URL?, size: CGFloat = 24) {
        self.url = url
        self.size = size
    }

    init(urlString: String?, size: CGFloat = 24) {
        self.url = urlString.flatMap { URL(string: $0) }
        self.size = size
    }

    private var fallbackView: some View {
        ZStack {
            Circle()
                .fill(Color.secondary.opacity(0.15))
            Image(systemName: "person.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.secondary)
                .padding(size * 0.1)
        }
        .frame(width: size, height: size)
    }

    var body: some View {
        KFImage(url)
            .placeholder { fallbackView }
            .onFailureImage(nil)
            .setProcessor(DownsamplingImageProcessor(size: CGSize(width: size * 3, height: size * 3)))
            .cacheOriginalImage()
            .fade(duration: 0.2)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
            .background(fallbackView)
    }
}
