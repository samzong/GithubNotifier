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

    var body: some View {
        KFImage(url)
            .placeholder {
                Circle()
                    .fill(Color.secondary.opacity(0.2))
            }
            .setProcessor(DownsamplingImageProcessor(size: CGSize(width: size * 3, height: size * 3)))
            .cacheOriginalImage()
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
    }
}
