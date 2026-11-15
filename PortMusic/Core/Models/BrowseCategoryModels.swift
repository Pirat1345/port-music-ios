import SwiftUI

// MARK: - Browse Category Models & Defaults (Matching Octave & Web 1:1)

public struct BrowseCategoryItem: Identifiable, Codable, Hashable {
    public let id: String
    public let title: String
    public let url: String?
    public let bgColor: String
    public let artworkUrl: String

    public init(id: String, title: String, url: String? = nil, bgColor: String, artworkUrl: String) {
        self.id = id
        self.title = title
        self.url = url
        self.bgColor = bgColor
        self.artworkUrl = artworkUrl
    }

    public var displayTitle: String {
        if title == "Apple Music Live" || title == "Arlo Parks: Apple Music Live" {
            return "Live Music"
        }
        return title
    }

    public var bannerUrl: String {
        if artworkUrl.contains("/600x600") {
            return artworkUrl.replacingOccurrences(of: "/600x600sr.jpg", with: "/640x320sr.jpg")
                             .replacingOccurrences(of: "/600x600bb.jpg", with: "/640x320sr.jpg")
        }
        return artworkUrl
    }

    public var color: Color {
        Color(hex: bgColor)
    }

    public var gradient: [Color] {
        [Color(hex: bgColor), Color(hex: bgColor).opacity(0.65)]
    }

    public var iconName: String {
        let t = title.lowercased()
        if t.contains("rock") { return "guitars.fill" }
        if t.contains("pop") { return "music.mic" }
        if t.contains("rap") || t.contains("hip-hop") { return "headphones" }
        if t.contains("dance") || t.contains("electro") { return "bolt.fill" }
        if t.contains("chill") { return "moon.fill" }
        if t.contains("hit") || t.contains("chart") { return "chart.bar.fill" }
        if t.contains("live") || t.contains("konzert") { return "waveform" }
        return "music.note"
    }

    // Default 44 curated Apple Music categories exactly matching frontend/src/data/browseCategories.ts
    public static let defaultCategories: [BrowseCategoryItem] = [
        BrowseCategoryItem(
            id: "6821956535",
            title: "Live Music",
            url: "https://music.apple.com/de/multi-room/6821942765",
            bgColor: "#c5c6c9",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features/v4/16/e0/d7/16e0d799-dd77-b8e1-cce3-f27f7664ead6/80e1dd92-de5f-424f-8e76-2144694ad6f3.png/600x600sr.jpg"
        ),
        BrowseCategoryItem(
            id: "1526756058",
            title: "Hits",
            url: "https://music.apple.com/de/curator/apple-music-hits/1526756058",
            bgColor: "#ddb71e",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features/v4/2e/18/a3/2e18a394-f9b2-1079-8d42-ccfa6d51d20d/88823a4b-bcc9-40c9-be1e-5671776d8837.png/600x600sr.jpg"
        ),
        BrowseCategoryItem(
            id: "1526867365",
            title: "Deutschrap",
            url: "https://music.apple.com/de/curator/apple-music-deutschrap/1526867365",
            bgColor: "#6b8ce9",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features/v4/3f/39/61/3f3961dd-2eea-eb27-a7f2-4b799218f227/313a61ae-8a20-4faf-9a5f-ede8bc713069.png/600x600sr.jpg"
        ),
        BrowseCategoryItem(
            id: "1558256251",
            title: "Chillen",
            url: "https://music.apple.com/de/curator/apple-music-chillen/1558256251",
            bgColor: "#28585e",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features221/v4/0f/17/d5/0f17d5a3-6774-1ae1-4530-2b694d8fb6bf/d7944211-2928-4ccc-b382-f0564bcf00b2.png/600x600sr.jpg"
        ),
        BrowseCategoryItem(
            id: "982308377",
            title: "Deutschpop",
            url: "https://music.apple.com/de/curator/apple-music-deutschpop/982308377",
            bgColor: "#e46689",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features/v4/48/a5/67/48a5677e-f0d2-cf36-2479-03c240f98fe8/9cee0055-90a3-4814-a7e7-1a46041a2d78.png/600x600sr.jpg"
        ),
        BrowseCategoryItem(
            id: "1514706977",
            title: "Charts",
            url: "https://itunes.apple.com/WebObjects/MZStore.woa/wa/viewTop?genreId=34",
            bgColor: "#595920",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features221/v4/62/61/c4/6261c465-fe72-eb32-5687-b7c015064b39/77b7bb43-5e28-4c40-afbc-97904ab8636a.png/600x600sr.jpg"
        ),
        BrowseCategoryItem(
            id: "988581996",
            title: "Rock",
            url: "https://music.apple.com/de/curator/apple-music-rock/988581996",
            bgColor: "#db6646",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features/v4/b6/13/a6/b613a6a2-0c03-cdb5-eef6-3f104e50ce86/aa8d0f82-c0d4-4a07-aae8-16f1db32c703.png/600x600sr.jpg"
        ),
        BrowseCategoryItem(
            id: "982307704",
            title: "Schlager",
            url: "https://music.apple.com/de/curator/apple-music-schlager/982307704",
            bgColor: "#e26486",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features/v4/f2/26/7a/f2267a42-c217-0675-d1f7-a8175dc0c7a9/aac76cf0-156a-4f3c-ac57-ffd127616bed.png/600x600sr.jpg"
        ),
        BrowseCategoryItem(
            id: "989066661",
            title: "Für Kinder",
            url: "https://music.apple.com/de/curator/apple-music-f%C3%BCr-kinder/989066661",
            bgColor: "#58b556",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features211/v4/89/1f/39/891f392b-f98b-b501-9f59-0e5668c9837e/74a588d5-9db5-4017-add7-ec2bfb02229e.png/600x600sr.jpg"
        ),
        BrowseCategoryItem(
            id: "6758165244",
            title: "Konzerte",
            url: "https://music.apple.com/concerts",
            bgColor: "#2e0001",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features221/v4/20/7a/cd/207acdb0-beaf-2a7b-81c0-643ae3c73bb7/a09e1918-cb88-4b25-9179-f38d15502d22.png/600x600sr.jpg"
        ),
        BrowseCategoryItem(
            id: "1897035519",
            title: "Halloween",
            url: "https://music.apple.com/de/curator/apple-music-halloween/1897035519",
            bgColor: "#081210",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features/v4/0b/95/10/0b951022-aed4-9074-2781-7f94015c07f7/7cbf0a59-9e6c-45f4-9937-120652dcd8dd.png/600x600sr.jpg"
        ),
        BrowseCategoryItem(
            id: "1798261090",
            title: "Apple Music für DJs",
            url: "https://music.apple.com/de/curator/apple-music-f%C3%BCr-djs/1798261090",
            bgColor: "#1c0a39",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features/v4/89/fe/58/89fe58fb-f76b-e73d-f6e0-e53df2e1b38e/f44c2028-75ec-4194-8e5c-7db5b2a641cc.png/600x600sr.jpg"
        ),
        BrowseCategoryItem(
            id: "1532467784",
            title: "Up Next",
            url: "https://music.apple.com/de/curator/apple-music-up-next/1532467784",
            bgColor: "#f83046",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features221/v4/84/7e/01/847e0191-36b7-065d-c7f1-0b2611b18f40/5b2ec950-d757-443b-ae50-72b225dca479.png/600x600sr.jpg"
        ),
        BrowseCategoryItem(
            id: "1531543191",
            title: "Radio",
            url: "https://music.apple.com/de/curator/radio-auf-apple-music/1531543191",
            bgColor: "#fa3348",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features221/v4/89/93/a0/8993a06b-a67f-c94d-202e-5665f816017c/803719d9-332d-4ff0-8797-7ca5a0cd2a91.png/600x600sr.jpg"
        ),
        BrowseCategoryItem(
            id: "988589193",
            title: "Pop",
            url: "https://music.apple.com/de/curator/apple-music-pop/988589193",
            bgColor: "#e46689",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features/v4/61/b3/04/61b3042d-bc19-8d6b-a32d-5f34ac93df3f/5c673bb5-5bd1-46fe-8e5c-201caf9517ee.png/600x600sr.jpg"
        ),
        BrowseCategoryItem(
            id: "988658197",
            title: "K-Pop",
            url: "https://music.apple.com/de/curator/apple-music-k-pop/988658197",
            bgColor: "#e46689",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features/v4/e9/e0/c3/e9e0c34a-fce2-e57e-dedd-d8c50f6fd56b/d45795a3-170d-4a39-bbf3-f47c69cfc4e4.png/600x600sr.jpg"
        ),
        BrowseCategoryItem(
            id: "982308048",
            title: "Französischer Pop",
            url: "https://music.apple.com/de/curator/apple-music-franz%C3%B6sischer-pop/982308048",
            bgColor: "#e46689",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features/v4/81/8a/79/818a7953-ad0f-74a4-7d47-df4427e0c31f/605767a7-f604-48bb-92ea-a0e5323f2b1f.png/600x600sr.jpg"
        ),
        BrowseCategoryItem(
            id: "988658201",
            title: "Metal",
            url: "https://music.apple.com/de/curator/apple-music-metal/988658201",
            bgColor: "#b03634",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features211/v4/01/55/73/015573af-3b08-ec3c-eef0-5d86d82d1d10/626ecaba-f2a8-447e-845d-b30e3bbef802.png/600x600sr.jpg"
        ),
        BrowseCategoryItem(
            id: "976439531",
            title: "Classic Rock",
            url: "https://music.apple.com/de/curator/apple-music-classic-rock/976439531",
            bgColor: "#dd6848",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features/v4/ee/0f/04/ee0f04df-41fa-5a91-346d-677baf0703d0/aa4c4050-2b2a-475e-ab94-89f70c4c5a11.png/600x600sr.jpg"
        ),
        BrowseCategoryItem(
            id: "979231690",
            title: "Hard Rock",
            url: "https://music.apple.com/de/curator/apple-music-hard-rock/979231690",
            bgColor: "#dd6848",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features221/v4/79/d2/18/79d2181e-eb7d-f0ce-b02c-f591dbbcce03/161e14bd-ce16-4c43-90cb-d7b2951afc8f.png/600x600sr.jpg"
        ),
        BrowseCategoryItem(
            id: "976439550",
            title: "Punk",
            url: "https://music.apple.com/de/curator/apple-music-punk/976439550",
            bgColor: "#da5c39",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features116/v4/ec/ce/18/ecce1830-cc21-91a6-6e40-39870932122e/3f1c951d-f927-490a-b485-6a665965316e.png/600x600sr.jpg"
        ),
        BrowseCategoryItem(
            id: "976439534",
            title: "Country",
            url: "https://music.apple.com/de/curator/apple-music-country/976439534",
            bgColor: "#dd8519",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features/v4/02/01/be/0201be00-7644-4351-934a-5723b9ff4e35/f270cdf8-0460-4474-884d-ac5047f6ef54.png/600x600sr.jpg"
        ),
        BrowseCategoryItem(
            id: "1526866189",
            title: "Die 1980er-Jahre",
            url: "https://music.apple.com/de/curator/apple-music-1980er-jahre/1526866189",
            bgColor: "#ddb71e",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features/v4/b9/2a/3f/b92a3f4e-4ba2-34e4-da84-475490db27f3/9aa77357-2b06-46c3-8535-2df92845bf2b.png/600x600sr.jpg"
        ),
        BrowseCategoryItem(
            id: "1526866514",
            title: "Die 1990er-Jahre",
            url: "https://music.apple.com/de/curator/apple-music-1990er-jahre/1526866514",
            bgColor: "#dab10d",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features126/v4/56/76/fe/5676fe64-31df-9c55-de01-a7c56d6403a2/528a4036-1af7-493a-b506-c2937415aacc.png/600x600sr.jpg"
        ),
        BrowseCategoryItem(
            id: "1526866635",
            title: "Die 2000er-Jahre",
            url: "https://music.apple.com/de/curator/apple-music-2000er-jahre/1526866635",
            bgColor: "#dab10d",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features126/v4/e9/73/69/e97369b3-c68c-1047-6086-08ae0c747469/9d4f61ac-4d2f-4546-98b3-4db3b1ccb01b.png/600x600sr.jpg"
        ),
        BrowseCategoryItem(
            id: "1526866702",
            title: "Die 2010er-Jahre",
            url: "https://music.apple.com/de/curator/apple-music-2010er-jahre/1526866702",
            bgColor: "#dab10d",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features116/v4/17/9d/5e/179d5e31-c15a-08f8-78eb-a7e83ecbf2f0/d676ae15-36eb-4748-9a67-1bdb5ba8efaa.png/600x600sr.jpg"
        ),
        BrowseCategoryItem(
            id: "988574300",
            title: "Alternative",
            url: "https://music.apple.com/de/curator/apple-music-alternative/988574300",
            bgColor: "#c6bc00",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features/v4/f8/d1/28/f8d12833-1476-cb33-b89b-75d262991712/3f3101a1-6a44-4779-a111-81909b8588ce.png/600x600sr.jpg"
        ),
        BrowseCategoryItem(
            id: "988578699",
            title: "Akustisch",
            url: "https://music.apple.com/de/curator/apple-music-akustisch/988578699",
            bgColor: "#b3be23",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features/v4/d4/89/2c/d4892c12-cd81-073f-0e54-1b67f4b6bfab/986ce134-12c9-49dd-baf9-aafc2f5d8408.png/600x600sr.jpg"
        ),
        BrowseCategoryItem(
            id: "1747003654",
            title: "Afrobeats",
            url: "https://music.apple.com/de/curator/apple-music-afrobeats/1747003654",
            bgColor: "#98bd29",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features/v4/63/95/fa/6395fafe-aad2-a8e3-7165-fc5aff516a2d/4666d5a6-3933-489d-afc0-b2df0c9cf2ac.png/600x600sr.jpg"
        ),
        BrowseCategoryItem(
            id: "976439552",
            title: "Reggae",
            url: "https://music.apple.com/de/curator/apple-music-reggae/976439552",
            bgColor: "#7db63b",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features221/v4/c7/0b/fa/c70bfa1b-8e4a-7bee-8e68-fb7dec4d33ff/cb5908a8-e353-48e6-b5ab-9bf0afc9549a.png/600x600sr.jpg"
        ),
        BrowseCategoryItem(
            id: "976439587",
            title: "Weltweit",
            url: "https://music.apple.com/de/curator/apple-music-weltweit/976439587",
            bgColor: "#3d9543",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features116/v4/d7/a0/11/d7a011c4-eac7-8660-17a4-8c995f160d42/03ae5886-1c46-446b-b18f-95b9fe189d2d.png/600x600sr.jpg"
        ),
        BrowseCategoryItem(
            id: "1010399660",
            title: "Hörspiele",
            url: "https://music.apple.com/de/curator/apple-music-h%C3%B6rspiele/1010399660",
            bgColor: "#0c1e0c",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features116/v4/f3/31/ae/f331ae5e-8db4-8dab-ded0-ad2212f42866/71c703b5-8e0e-4771-b652-9247a44d12a4.png/600x600sr.jpg"
        ),
        BrowseCategoryItem(
            id: "1441811365",
            title: "DJ-Mixe",
            url: "https://music.apple.com/de/curator/apple-music-dj-mixe/1441811365",
            bgColor: "#3cbb7d",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features221/v4/b6/d7/0e/b6d70e68-795d-e4ff-e9b8-789f2afedb8b/a01002ad-4969-4751-8ced-b9824dce95a0.png/600x600sr.jpg"
        ),
        BrowseCategoryItem(
            id: "989075753",
            title: "Dance",
            url: "https://music.apple.com/de/curator/apple-music-dance/989075753",
            bgColor: "#3cbb7d",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features/v4/26/85/a8/2685a8e4-6117-8c07-8f6f-35e552cc52df/eb88fb05-6d0c-4dc6-b37e-9254f477760f.png/600x600sr.jpg"
        ),
        BrowseCategoryItem(
            id: "1013612753",
            title: "Electronic",
            url: "https://music.apple.com/de/curator/apple-electronic/1013612753",
            bgColor: "#3cbb7d",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features211/v4/7c/13/4d/7c134d34-1130-d9e8-d0a1-9f2371483ded/938a6e2e-b7e7-4762-acdf-cddd7ffc33dc.png/600x600sr.jpg"
        ),
        BrowseCategoryItem(
            id: "976439541",
            title: "Indie",
            url: "https://music.apple.com/de/curator/apple-music-indie/976439541",
            bgColor: "#00ba98",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features211/v4/6e/16/c9/6e16c931-af84-24a3-e648-017de74a6bd8/437bbe95-54b3-4be5-9881-dfb0547d2922.png/600x600sr.jpg"
        ),
        BrowseCategoryItem(
            id: "976439542",
            title: "Jazz",
            url: "https://music.apple.com/de/curator/apple-music-jazz/976439542",
            bgColor: "#29a5c9",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features221/v4/e5/e6/ff/e5e6ff02-99fd-9a2a-ebd2-6938500a6b3d/adeea72c-d032-40ca-a97d-57dbbc77276d.png/600x600sr.jpg"
        ),
        BrowseCategoryItem(
            id: "976439528",
            title: "Blues",
            url: "https://music.apple.com/de/curator/apple-music-blues/976439528",
            bgColor: "#4997d5",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features/v4/9f/cb/28/9fcb28ce-d34a-c841-78ec-79dd2067e6e7/1ba54c60-a74e-4511-a925-f7cffb00f6a9.png/600x600sr.jpg"
        ),
        BrowseCategoryItem(
            id: "989061403",
            title: "Hip-Hop/Rap International",
            url: "https://music.apple.com/de/curator/apple-music-hip-hop-rap-international/989061403",
            bgColor: "#6b8ce9",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features/v4/ee/9a/73/ee9a73e2-5514-895a-a94f-ec22bbbf1f91/1dcdf31e-a624-48dd-b5f2-40c7447fa105.png/600x600sr.jpg"
        ),
        BrowseCategoryItem(
            id: "1526867629",
            title: "Französischer Rap",
            url: "https://music.apple.com/de/curator/apple-music-franz%C3%B6sischer-rap/1526867629",
            bgColor: "#6b8ce9",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features/v4/b7/38/45/b73845f9-f1b0-c62a-36bd-17d0c22ed3aa/a727af66-973c-453c-9aa4-9ea4f6ad211b.png/600x600sr.jpg"
        ),
        BrowseCategoryItem(
            id: "976439585",
            title: "Soul/Funk",
            url: "https://music.apple.com/de/curator/apple-music-soul-funk/976439585",
            bgColor: "#8280e7",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features221/v4/b4/63/1b/b4631b83-b21d-113b-3a94-6c4389fb2629/8a0898cb-faa2-44c0-bed8-bdf1f4c76a32.png/600x600sr.jpg"
        ),
        BrowseCategoryItem(
            id: "1013624291",
            title: "R&B",
            url: "https://music.apple.com/de/curator/apple-music-r-b/1013624291",
            bgColor: "#8e75d8",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features/v4/88/d9/c4/88d9c404-dd31-2d21-b590-3b5818bea779/dfef34f3-8cf5-4a2b-ab2a-c2ad39ee3da3.png/600x600sr.jpg"
        ),
        BrowseCategoryItem(
            id: "982302294",
            title: "Anime",
            url: "https://music.apple.com/de/curator/apple-music-anime/982302294",
            bgColor: "#a376e4",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features221/v4/3e/2a/75/3e2a753a-492c-f34b-aa2d-4a66bd678f32/500aa611-84c4-49de-ac80-8dde30262fd1.png/600x600sr.jpg"
        ),
        BrowseCategoryItem(
            id: "1878215041",
            title: "Alpha Women",
            url: "https://music.apple.com/de/curator/alpha-women/1878215041",
            bgColor: "#751ba6",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features/v4/63/73/36/6373363b-f7f8-5b7d-60ce-bd6e301eb0b6/758060f1-9b25-4058-ae5c-cf7478409f9d.png/600x600sr.jpg"
        ),
        BrowseCategoryItem(
            id: "989071401",
            title: "Klassik",
            url: "https://music.apple.com/de/curator/apple-music-classical/989071401",
            bgColor: "#aa68d1",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features/v4/b8/73/3a/b8733a13-c091-44fa-a69c-fa81c86e4058/5cee7caf-28f6-4bb8-bbef-b260f0ef791e.png/600x600sr.jpg"
        ),
        BrowseCategoryItem(
            id: "1558256771",
            title: "Essentials",
            url: "https://music.apple.com/de/curator/apple-music-essentials/1558256771",
            bgColor: "#8f3789",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features221/v4/58/c5/65/58c56545-8e10-3dae-8366-413f5e6ccfb6/b771b992-12bc-4d24-85f1-63e4a4de5688.png/600x600sr.jpg"
        ),
        BrowseCategoryItem(
            id: "1558257035",
            title: "Party",
            url: "https://music.apple.com/de/curator/apple-music-party/1558257035",
            bgColor: "#9f3873",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features211/v4/13/12/7d/13127dc4-9c81-099c-31a7-afb849518840/06e568d2-c588-448f-8721-1739e6ac2f2f.png/600x600sr.jpg"
        ),
        BrowseCategoryItem(
            id: "1558257257",
            title: "Einschlafen",
            url: "https://music.apple.com/de/curator/apple-music-einschlafen/1558257257",
            bgColor: "#4e246e",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features211/v4/66/44/63/6644636a-6134-e464-32e6-a7900d583ce8/bcb74429-1303-4fb0-9c3f-a6f0b87eb86e.png/600x600sr.jpg"
        ),
        BrowseCategoryItem(
            id: "1558256865",
            title: "Tristesse",
            url: "https://music.apple.com/de/curator/apple-music-tristesse/1558256865",
            bgColor: "#1e2d4c",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features211/v4/d7/50/a1/d750a1ff-7379-8129-edf4-1cabab7e7dd4/79edca2f-34d6-4d0e-b8a3-85a170222b35.png/600x600sr.jpg"
        ),
        BrowseCategoryItem(
            id: "1558256909",
            title: "Fitness",
            url: "https://music.apple.com/de/curator/apple-music-fitness/1558256909",
            bgColor: "#808a20",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features221/v4/cf/2f/ef/cf2fef65-9f86-d368-eedc-d18ad4511069/301c121f-9f4a-4de4-8f2d-f3253ee7fb3a.png/600x600sr.jpg"
        )
    ]
}

// MARK: - Apple Category Detail Response Models (/api/category/:id)

public struct AppleCategoryDetailData: Codable, Identifiable {
    public let id: String
    public let title: String
    public let heroArtwork: String?
    public let bgColor: String?
    public let sections: [AppleCategorySection]

    public init(id: String, title: String, heroArtwork: String? = nil, bgColor: String? = nil, sections: [AppleCategorySection] = []) {
        self.id = id
        self.title = title
        self.heroArtwork = heroArtwork
        self.bgColor = bgColor
        self.sections = sections
    }
}

public struct AppleCategorySection: Codable, Identifiable {
    public var id: String { title }
    public let title: String
    public let items: [AppleCategorySectionItem]

    public init(title: String, items: [AppleCategorySectionItem]) {
        self.title = title
        self.items = items
    }
}

public struct AppleCategorySectionItem: Codable, Identifiable {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let cover: String?
    public let kind: String

    public init(id: String, title: String, subtitle: String? = nil, cover: String? = nil, kind: String = "track") {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.cover = cover
        self.kind = kind
    }

    public func toTrack() -> Track {
        Track(
            id: id,
            title: title,
            artist: subtitle ?? "Port Music",
            coverUrl: cover
        )
    }
}
