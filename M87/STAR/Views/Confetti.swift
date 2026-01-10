import SwiftUI

struct Confetti {
    let angle: Angle
    let radius: Double
    let steps: Int
    let ySpeed: Double
    let color: Color
    let waveFrequency = Double.random(in: 0...0.2)
    let waveSpeed = Double.random(in: 0...0.1)

    private(set) var opacity: Double = 1
    private(set) var x: Double
    private(set) var y: Double

    private var stepsTaken: Int = 0
    private var isFalling = false
    private var wave: Double = 0

    init(angle: Angle, radius: Double, steps: Int, ySpeed: Double, x: Double, y: Double, color: Color) {
        self.angle = angle
        self.radius = radius
        self.steps = steps
        self.ySpeed = ySpeed
        self.x = x
        self.y = y
        self.color = color
    }

    mutating func step() {
        guard opacity > 0 else { return }

        if isFalling {
            x += waveFrequency * sin(wave)
            wave += waveSpeed
            y += ySpeed
            opacity = max(opacity - 0.001, 0)
        } else {
            if stepsTaken >= steps {
                isFalling = true
                return
            }
            
            x += (radius / Double(steps)) * cos(angle.radians)
            y -= (radius / Double(steps)) * sin(angle.radians)
            stepsTaken += 1
        }
    }
}

struct ConfettiView: View {
    @State var confettis: [Confetti] = []
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        Text("")
            .onAppear() {
                for _ in 0...100 {
                    confettis.append(Confetti(angle: .degrees(Double.random(in: -30...210)), radius: Double.random(in: 50...120) + min(width, height)/50, steps: 20, ySpeed: Double.random(in: 0.1...0.5), x: Double(width)/2, y: Double(height)/2, color: RGB(rand: true)))
                }
            }
        TimelineView(.animation) { timeline in

            // ✅ DRAW PHASE
            Canvas { context, _ in
                for confetti in confettis {
                    let rect = CGRect(
                        x: confetti.x,
                        y: confetti.y,
                        width: 5,
                        height: 5
                    )

                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(confetti.color.opacity(confetti.opacity))
                    )
                }
            }
            .onChange(of: timeline.date, {
                for i in confettis.indices {
                    confettis[i].step()
                }
            })
        }
        .frame(width: width, height: height)
    }
}

#Preview {
    ConfettiView(width: 500, height: 300)
}
