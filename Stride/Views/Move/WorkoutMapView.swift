import MapKit
import SwiftUI

struct WorkoutMapView: View {
    let coordinates: [CLLocationCoordinate2D]
    let tint: Color
    var followsUser: Bool = false
    var showsStartFinish: Bool = false

    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)

    var body: some View {
        Map(position: $position) {
            if coordinates.count > 1 {
                MapPolyline(coordinates: coordinates)
                    .stroke(tint, lineWidth: 5)
            }
            if showsStartFinish, let start = coordinates.first {
                Annotation("Start", coordinate: start) {
                    Circle()
                        .fill(.white)
                        .overlay(Circle().stroke(tint, lineWidth: 3))
                        .frame(width: 16, height: 16)
                }
            }
            if showsStartFinish, coordinates.count > 1, let end = coordinates.last {
                Annotation("Finish", coordinate: end) {
                    Circle()
                        .fill(tint)
                        .frame(width: 16, height: 16)
                }
            }
            if followsUser {
                UserAnnotation()
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll, showsTraffic: false))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .onAppear {
            if followsUser {
                position = .userLocation(fallback: .automatic)
            } else if let region = regionFittingCoordinates {
                position = .region(region)
            }
        }
        .onChange(of: coordinates.count) { _, _ in
            guard !followsUser, let region = regionFittingCoordinates else { return }
            position = .region(region)
        }
    }

    private var regionFittingCoordinates: MKCoordinateRegion? {
        guard let first = coordinates.first else { return nil }
        var minLat = first.latitude
        var maxLat = first.latitude
        var minLon = first.longitude
        var maxLon = first.longitude
        for coordinate in coordinates {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.4, 0.005),
            longitudeDelta: max((maxLon - minLon) * 1.4, 0.005)
        )
        return MKCoordinateRegion(center: center, span: span)
    }
}
