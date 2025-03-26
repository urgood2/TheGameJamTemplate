#include <cmath>
#include <vector>
#include <utility>
#include <algorithm>
#include <stdexcept>

namespace math {

    // Checks if a point is colliding with a line.
    // math.point_line(0, 0, 0, 0, 2, 2) -> true
    // math.point_line(1, 1, 4, 5, 6, 6) -> false
    bool point_line(double px, double py, double x1, double y1, double x2, double y2) {
        double crossProduct = (py - y1) * (x2 - x1) - (px - x1) * (y2 - y1);
        if (std::abs(crossProduct) > 1e-8) return false;

        double dotProduct = (px - x1) * (x2 - x1) + (py - y1) * (y2 - y1);
        if (dotProduct < 0) return false;

        double squaredLength = std::pow(x2 - x1, 2) + std::pow(y2 - y1, 2);
        return dotProduct <= squaredLength;
    }

    // Checks if a point is colliding with a circle.
    // math.point_circle(0, 0, 0, 0, 2) -> true
    // math.point_circle(-2, 0, 0, 0, 2) -> true
    // math.point_circle(10, 10, 0, 0, 2) -> false
    bool point_circle(double px, double py, double cx, double cy, double rs) {
        double distSquared = (px - cx) * (px - cx) + (py - cy) * (py - cy);
        return distSquared <= rs * rs;
    }

    // Checks if two lines are colliding.
    // math.line_line(0, 0, 2, 2, 0, 2, 2, 0) -> true
    // math.line_line(0, 0, 2, 2, 0, 0, 2, 2) -> true
    // math.line_line(0, 0, 2, 2, 10, 10, 12, 12) -> false
    bool line_line(double x1, double y1, double x2, double y2, double x3, double y3, double x4, double y4) {
        auto det = [](double a, double b, double c, double d) {
            return a * d - b * c;
        };
        double detL1 = det(x1, y1, x2, y2);
        double detL2 = det(x3, y3, x4, y4);
        double x1mx2 = x1 - x2, x3mx4 = x3 - x4;
        double y1my2 = y1 - y2, y3my4 = y3 - y4;

        double denom = det(x1mx2, y1my2, x3mx4, y3my4);
        if (denom == 0.0) return false; // Parallel lines

        double px = det(detL1, x1mx2, detL2, x3mx4) / denom;
        double py = det(detL1, y1my2, detL2, y3my4) / denom;

        if ((px < std::min(x1, x2) || px > std::max(x1, x2)) || 
            (px < std::min(x3, x4) || px > std::max(x3, x4))) return false;

        return true;
    }

    // Snaps a value to the closest number divisible by x.
    // math.snap(15, 16) -> 0
    // math.snap(17, 16) -> 16
    // math.snap(13, 4) -> 12
    double snap(double v, double x) {
        return std::round(v / x) * x;
    }

    // Converts a direction as a string ('left', 'right', 'up', 'down') to its corresponding angle.
    // math.direction_to_angle('left') -> math.pi
    // math.direction_to_angle('up') -> -math.pi/2
    // math.direction_to_angle('right') -> 0
    double direction_to_angle(const std::string &dir) {
        if (dir == "left") return M_PI;
        if (dir == "right") return 0;
        if (dir == "up") return -M_PI / 2;
        if (dir == "down") return M_PI / 2;
        throw std::invalid_argument("Invalid direction string.");
    }

    // Checks if a point is colliding with a polygon.
    // math.point_polygon(0, 0, -1, -1, 1, -1, 0, 2) -> true
    // math.point_polygon(10, 10, -1, -1, 1, -1, 0, 2) -> false
    // math.point_polygon(-1, -1, -1, -1, 1, -1, 0, 2) -> true
    bool point_polygon(double px, double py, const std::vector<std::pair<double, double>>& vertices) {
        int intersections = 0;
        size_t n = vertices.size();

        for (size_t i = 0; i < n; ++i) {
            auto [x1, y1] = vertices[i];
            auto [x2, y2] = vertices[(i + 1) % n];

            if (y1 > py != y2 > py && px < (x2 - x1) * (py - y1) / (y2 - y1) + x1) {
                intersections++;
            }
        }

        return intersections % 2 != 0;
    }

    // Checks if a line is colliding with a circle.
    // math.line_circle(0, 0, 2, 0, 2, 0, 1) -> true
    // math.line_circle(0, 0, 2, 0, 4, 0, 2) -> true
    // math.line_circle(0, 0, 2, 0, 8, 0, 2) -> false
    bool line_circle(double x1, double y1, double x2, double y2, double cx, double cy, double r) {
        double dx = x2 - x1;
        double dy = y2 - y1;

        double fx = x1 - cx;
        double fy = y1 - cy;

        double a = dx * dx + dy * dy;
        double b = 2 * (fx * dx + fy * dy);
        double c = fx * fx + fy * fy - r * r;

        double discriminant = b * b - 4 * a * c;
        if (discriminant < 0) return false;

        discriminant = std::sqrt(discriminant);
        double t1 = (-b - discriminant) / (2 * a);
        double t2 = (-b + discriminant) / (2 * a);

        if (t1 >= 0 && t1 <= 1) return true;
        if (t2 >= 0 && t2 <= 1) return true;

        return false;
    }

    // Checks if two circles are colliding.
    // math.circle_circle(0, 0, 2, 1, 0, 2) -> true
    // math.circle_circle(0, 0, 2, 0, 0, 1) -> true
    // math.circle_circle(0, 0, 2, 4, 0, 2) -> true
    // math.circle_circle(0, 0, 2, 8, 0, 2) -> false
    bool circle_circle(double x1, double y1, double r1, double x2, double y2, double r2) {
        double combinedRadius = r1 + r2;
        return (x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1) <= combinedRadius * combinedRadius;
    }

    // Checks if a line is colliding with a polygon.
    // math.line_polygon(-10, 0, -4, 0, -4, -4, 4, -4, 4, 4, -4, 4)
    // math.line_polygon(0, 0, 2, 0, -4, -4, 4, -4, 4, 4, -4, 4)
    bool line_polygon(double x1, double y1, double x2, double y2, const std::vector<std::pair<double, double>>& vertices) {
        size_t n = vertices.size();
        for (size_t i = 0; i < n; ++i) {
            auto [vx1, vy1] = vertices[i];
            auto [vx2, vy2] = vertices[(i + 1) % n];
            if (line_line(x1, y1, x2, y2, vx1, vy1, vx2, vy2)) return true;
        }
        return point_polygon((x1 + x2) / 2, (y1 + y2) / 2, vertices);
    }

    // Returns the polygon's width and height.
    // math.get_polygon_size(...) -> the width and height of the polygon (its bounding box)
    std::pair<double, double> get_polygon_size(const std::vector<std::pair<double, double>>& vertices) {
        double min_x = std::numeric_limits<double>::max();
        double min_y = std::numeric_limits<double>::max();
        double max_x = std::numeric_limits<double>::lowest();
        double max_y = std::numeric_limits<double>::lowest();

        for (const auto& [x, y] : vertices) {
            min_x = std::min(min_x, x);
            min_y = std::min(min_y, y);
            max_x = std::max(max_x, x);
            max_y = std::max(max_y, y);
        }

        return {max_x - min_x, max_y - min_y};
    }

    // Generates points in the area centered around x, y with size w, h, with each point having a minimum distance of rs from each other.
    // Based on https://www.youtube.com/watch?v=7WcmyxyFO7o
    std::vector<std::pair<double, double>> generate_poisson_disc_sampled_points_2d(
        double rs, double x, double y, double w, double h) {
        
        double cell_size = rs / std::sqrt(2);
        int grid_width = static_cast<int>(w / cell_size);
        int grid_height = static_cast<int>(h / cell_size);

        std::vector<std::vector<int>> grid(grid_width, std::vector<int>(grid_height, -1));
        std::vector<std::pair<double, double>> points;
        std::vector<std::pair<double, double>> spawn_points;

        auto is_valid = [&](double px, double py) -> bool {
            if (px < 0 || px > w || py < 0 || py > h) return false;
            int gx = static_cast<int>(px / cell_size);
            int gy = static_cast<int>(py / cell_size);

            int min_x = std::max(0, gx - 2);
            int max_x = std::min(grid_width - 1, gx + 2);
            int min_y = std::max(0, gy - 2);
            int max_y = std::min(grid_height - 1, gy + 2);

            for (int i = min_x; i <= max_x; ++i) {
                for (int j = min_y; j <= max_y; ++j) {
                    if (grid[i][j] != -1) {
                        double dx = points[grid[i][j]].first - px;
                        double dy = points[grid[i][j]].second - py;
                        if (std::sqrt(dx * dx + dy * dy) < rs) {
                            return false;
                        }
                    }
                }
            }
            return true;
        };

        spawn_points.emplace_back(w / 2, h / 2);

        while (!spawn_points.empty()) {
            int spawn_index = rand() % spawn_points.size();
            auto [sx, sy] = spawn_points[spawn_index];
            bool accepted = false;

            for (int i = 0; i < 30; ++i) {
                double angle = static_cast<double>(rand()) / RAND_MAX * 2 * M_PI;
                double radius = rs + static_cast<double>(rand()) / RAND_MAX * rs;
                double nx = sx + radius * std::cos(angle);
                double ny = sy + radius * std::sin(angle);

                if (is_valid(nx, ny)) {
                    points.emplace_back(nx, ny);
                    spawn_points.emplace_back(nx, ny);
                    int gx = static_cast<int>(nx / cell_size);
                    int gy = static_cast<int>(ny / cell_size);
                    grid[gx][gy] = points.size() - 1;
                    accepted = true;
                    break;
                }
            }

            if (!accepted) {
                spawn_points.erase(spawn_points.begin() + spawn_index);
            }
        }

        for (auto& point : points) {
            point.first += x - w / 2;
            point.second += y - h / 2;
        }

        return points;
    }

    // Generates bezier curves that pass through the provided points.
    // Based on https://love2d.org/forums/viewtopic.php?p=228432#p228432
    std::vector<std::vector<std::pair<double, double>>> generate_curves(
        const std::vector<std::pair<double, double>>& points,
        double tension = 0, double continuity = 0, double bias = 0) {

        if (points.size() < 3) {
            throw std::invalid_argument("generate_curves needs at least 3 points");
        }

        auto kochanek_bartels = [](double x1, double y1, double x2, double y2, double x3, double y3, double x4, double y4,
                                   double t, double c, double b) {
            double _x1 = x2;
            double _y1 = y2;

            double _x2 = x2 + ((1 - t) * (1 + b) * (1 + c) * (x2 - x1) + (1 - t) * (1 - b) * (1 - c) * (x3 - x2)) / 6;
            double _y2 = y2 + ((1 - t) * (1 + b) * (1 + c) * (y2 - y1) + (1 - t) * (1 - b) * (1 - c) * (y3 - y2)) / 6;

            double _x3 = x3 - ((1 - t) * (1 + b) * (1 - c) * (x3 - x2) + (1 - t) * (1 - b) * (1 + c) * (x4 - x3)) / 6;
            double _y3 = y3 - ((1 - t) * (1 + b) * (1 - c) * (y3 - y2) + (1 - t) * (1 - b) * (1 + c) * (y4 - y3)) / 6;

            double _x4 = x3;
            double _y4 = y3;

            return std::vector<std::pair<double, double>>{{_x1, _y1}, {_x2, _y2}, {_x3, _y3}, {_x4, _y4}};
        };

        std::vector<std::vector<std::pair<double, double>>> curves;

        for (size_t i = 1; i < points.size() - 2; ++i) {
            curves.push_back(kochanek_bartels(
                points[i - 1].first, points[i - 1].second,
                points[i].first, points[i].second,
                points[i + 1].first, points[i + 1].second,
                points[i + 2].first, points[i + 2].second,
                tension, continuity, bias));
        }

        return curves;
    }

    // Returns the 2D coordinates of a given index with a grid of a given width
    // math.index_to_coordinates(11, 10) -> 1, 2
    // math.index_to_coordinates(2, 4) -> 2, 1
    std::pair<int, int> index_to_coordinates(int index, int width) {
        int x = (index - 1) % width + 1;
        int y = (index - 1) / width + 1;
        return {x, y};
    }

    // Returns the 1D index of the given 2D coordinates with a grid of a given width
    // math.coordinates_to_index(1, 2, 10) -> 11
    // math.coordinates_to_index(2, 1, 4) -> 2
    int coordinates_to_index(int x, int y, int width) {
        return (y - 1) * width + x;
    }

    // Rotates the point by r radians with ox, oy as pivot.
    // x, y = math.rotate_point(player.x, player.y, math.pi/4)
    std::pair<double, double> rotate_point(double x, double y, double r, double ox = 0, double oy = 0) {
        double cos_r = std::cos(r);
        double sin_r = std::sin(r);
        double nx = cos_r * (x - ox) - sin_r * (y - oy) + ox;
        double ny = sin_r * (x - ox) + cos_r * (y - oy) + oy;
        return {nx, ny};
    }

    // Scales the point by sx, sy with ox, oy as pivot.
    // x, y = math.scale_point(player.x, player.y, 2, 2, player.x - player.w/2, player.y - player.h/2)
    std::pair<double, double> scale_point(double x, double y, double sx, double sy, double ox = 0, double oy = 0) {
        double nx = sx * (x - ox) + ox;
        double ny = sy * (y - oy) + oy;
        return {nx, ny};
    }

    // Rotates and scales the point by r radians and sx, sy with ox, oy as pivot.
    // x, y = math.rotate_scale_point(player.x, player.y, math.pi/4, 2, 2, player.x - player.w/2, player.y - player.h/2)
    std::pair<double, double> rotate_scale_point(double x, double y, double r, double sx, double sy, double ox = 0, double oy = 0) {
        auto rotated = rotate_point(x, y, r, ox, oy);
        return scale_point(rotated.first, rotated.second, sx, sy, ox, oy);
    }

    // Wraps value v such that it is never below 1 or above x.
    // math.wrap(1, 3) -> 1
    // math.wrap(5, 3) -> 2
    double wrap(double v, double x) {
        return std::fmod((std::fmod(v - 1, x) + x), x) + 1;
    }

    // Clamps value v between min and max.
    // math.clamp(-4, 0, 10) -> 0
    // math.clamp(83, 0, 10) -> 10
    double clamp(double v, double min_val, double max_val) {
        return std::max(min_val, std::min(v, max_val));
    }

    // Returns the squared length of x, y.
    // math.length_squared(x, y)
    double length_squared(double x, double y) {
        return x * x + y * y;
    }

    // Returns the normalized values of x, y.
    // nx, ny = math.normalize(x, y)
    std::pair<double, double> normalize(double x, double y) {
        double length = std::sqrt(x * x + y * y);
        if (length < 1e-8) return {x, y}; // Avoid division by zero
        return {x / length, y / length};
    }

    // Returns the x, y values truncated by max.
    // x, y = math.limit(x, y, 100)
    std::pair<double, double> limit(double x, double y, double max) {
        double len_squared = length_squared(x, y);
        if (len_squared > max * max) {
            double scale = max / std::sqrt(len_squared);
            return {x * scale, y * scale};
        }
        return {x, y};
    }

    // Lerps src to dst with lerp value.
    // v = math.lerp(0.2, self.x, self.x + 100)
    double lerp(double value, double src, double dst) {
        return src * (1 - value) + dst * value;
    }

    // Remaps value v using its previous range of old_min, old_max into the new range new_min, new_max.
    // v = math.remap(10, 0, 20, 0, 1) -> 0.5
    double remap(double v, double old_min, double old_max, double new_min, double new_max) {
        return ((v - old_min) / (old_max - old_min)) * (new_max - new_min) + new_min;
    }

    // Loops value t such that it is never higher than length and never lower than 0.
    // v = math.loop(3, 2.5) -> 0.5
    double loop(double t, double length) {
        return t - std::floor(t / length) * length;
    }

    // Returns the smallest difference between two angles.
    // math.angle_delta(math.pi, math.pi/4) -> 3*math.pi/4
    double angle_delta(double a, double b) {
        double d = loop(a - b, 2 * M_PI);
        if (d > M_PI) d -= 2 * M_PI;
        return d;
    }

    // Lerps the src angle towards dst using value as the lerp amount.
    // math.lerp_angle(0.2, src_angle, dst_angle)
    double lerp_angle(double value, double src, double dst) {
        double delta = angle_delta(dst, src);
        return src + delta * clamp(value, 0.0, 1.0);
    }

    // Same as math.lerp_angle, corrected for usage with delta time.
    // math.lerp_angle_dt(1, dt, src_angle, dst_angle)
    double lerp_angle_dt(double f, double dt, double src, double dst) {
        double lerp_value = 1 - std::exp(-f * dt);
        return lerp_angle(lerp_value, src, dst);
    }

    // Calculates correct dampened position values given the old position, velocity, damping, and delta time.
    // x, y = math.position_damping(x, y, vx, vy, damping, dt)
    std::pair<double, double> position_damping(double x, double y, double vx, double vy, double damping, double dt) {
        double factor = (std::pow(damping, dt) - 1) / std::log(damping);
        return {x + vx * factor, y + vy * factor};
    }

    // Calculates correct dampened velocity values given the old velocity, damping, and delta time.
    // vx, vy = math.velocity_damping(vx, vy, damping, dt)
    std::pair<double, double> velocity_damping(double vx, double vy, double damping, double dt) {
        double factor = std::pow(damping, dt);
        return {vx * factor, vy * factor};
    }

    // Calculates correct dampened values for the given variable, with damping and delta time.
    // v = math.damping(value, damping, dt)
    double damping(double value, double damping, double dt) {
        return value * std::pow(damping, dt);
    }

    // Calculates a new velocity based on the previous velocity, acceleration, drag, max velocity, and delta time.
    // v = math.compute_velocity(v, a, drag, max_v, dt)
    double compute_velocity(double v, double a, double drag, double max_v, double dt) {
        if (a != 0) {
            v += a * dt;
        } else if (drag != 0) {
            double drag_effect = drag * dt;
            if (v > 0) {
                v = std::max(0.0, v - drag_effect);
            } else {
                v = std::min(0.0, v + drag_effect);
            }
        }
        if (max_v != 0) {
            v = clamp(v, -max_v, max_v);
        }
        return v;
    }

    // Given an angle r and normal values nx, ny, calculate the bounce angle.
    // math.bounce(r, nx, ny)
    double bounce(double r, double nx, double ny) {
        if (nx == 0) {
            return 2 * M_PI - r;
        } else if (ny == 0) {
            return M_PI - r;
        }
        return r;
    }

    // Given two angles r1 and r2, returns the middle angle between them.
    // math.angle_mid(r1, r2)
    double angle_mid(double r1, double r2) {
        double cos_sum = std::cos(r1) + std::cos(r2);
        double sin_sum = std::sin(r1) + std::sin(r2);
        return std::atan2(sin_sum, cos_sum);
    }

    // Loops value t such that it is never higher than length and never lower than 0.
    // math.loop(t, length)
    double loop(double t, double length) {
        return std::fmod(std::fmod(t, length) + length, length);
    }

    // Returns the smallest difference between two angles.
    // math.angle_delta(a, b)
    double angle_delta(double a, double b) {
        double d = loop(a - b, 2 * M_PI);
        if (d > M_PI) d -= 2 * M_PI;
        return d;
    }

    constexpr double PI = 3.14159265358979323846;
    constexpr double PI2 = PI / 2.0;
    constexpr double LN2 = std::log(2.0);
    constexpr double LN210 = 10.0 * LN2;

    // Helper functions
    inline double clamp(double v, double min, double max) {
        return std::max(min, std::min(v, max));
    }

    inline double loop(double t, double length) {
        return t - std::floor(t / length) * length;
    }

    inline double sign(double v) {
        if (v > 0) return 1;
        if (v < 0) return -1;
        return 0;
    }

    inline double length(double x, double y) {
        return std::sqrt(x * x + y * y);
    }

    // Checks if a point is colliding with a line.
    bool point_line(double px, double py, double x1, double y1, double x2, double y2) {
        double dx = x2 - x1, dy = y2 - y1;
        double len_squared = dx * dx + dy * dy;
        if (len_squared == 0) return false;

        double t = ((px - x1) * dx + (py - y1) * dy) / len_squared;
        return t >= 0 && t <= 1;
    }

    // Checks if a point is colliding with a circle.
    bool point_circle(double px, double py, double cx, double cy, double radius) {
        double dx = px - cx, dy = py - cy;
        return dx * dx + dy * dy <= radius * radius;
    }

    // Checks if two lines intersect.
    bool line_line(double x1, double y1, double x2, double y2, double x3, double y3, double x4, double y4) {
        double denom = (y4 - y3) * (x2 - x1) - (x4 - x3) * (y2 - y1);
        if (denom == 0) return false;

        double ua = ((x4 - x3) * (y1 - y3) - (y4 - y3) * (x1 - x3)) / denom;
        double ub = ((x2 - x1) * (y1 - y3) - (y2 - y1) * (x1 - x3)) / denom;

        return ua >= 0 && ua <= 1 && ub >= 0 && ub <= 1;
    }

    // Checks if a line intersects with a circle.
    bool line_circle(double x1, double y1, double x2, double y2, double cx, double cy, double radius) {
        double dx = x2 - x1, dy = y2 - y1;
        double len_squared = dx * dx + dy * dy;
        if (len_squared == 0) return false;

        double t = ((cx - x1) * dx + (cy - y1) * dy) / len_squared;
        t = clamp(t, 0, 1);

        double nearest_x = x1 + t * dx;
        double nearest_y = y1 + t * dy;

        double dist_x = cx - nearest_x, dist_y = cy - nearest_y;
        return dist_x * dist_x + dist_y * dist_y <= radius * radius;
    }

    // Generates Poisson-disc sampled points within a 2D area.
    std::vector<std::pair<double, double>> generate_poisson_disc_points(
        double radius, double width, double height, int max_attempts = 30) {
        double cell_size = radius / std::sqrt(2.0);
        int grid_width = static_cast<int>(std::ceil(width / cell_size));
        int grid_height = static_cast<int>(std::ceil(height / cell_size));

        std::vector<int> grid(grid_width * grid_height, -1);
        std::vector<std::pair<double, double>> points;
        std::vector<std::pair<double, double>> spawn_points;

        auto is_valid = [&](double x, double y) {
            if (x < 0 || x > width || y < 0 || y > height) return false;

            int gx = static_cast<int>(x / cell_size);
            int gy = static_cast<int>(y / cell_size);

            int min_x = std::max(0, gx - 2);
            int max_x = std::min(grid_width - 1, gx + 2);
            int min_y = std::max(0, gy - 2);
            int max_y = std::min(grid_height - 1, gy + 2);

            for (int i = min_x; i <= max_x; ++i) {
                for (int j = min_y; j <= max_y; ++j) {
                    int idx = i + j * grid_width;
                    if (grid[idx] != -1) {
                        double px = points[grid[idx]].first;
                        double py = points[grid[idx]].second;
                        double dx = x - px, dy = y - py;
                        if (dx * dx + dy * dy < radius * radius) {
                            return false;
                        }
                    }
                }
            }
            return true;
        };

        spawn_points.emplace_back(width / 2, height / 2);

        while (!spawn_points.empty()) {
            int spawn_index = rand() % spawn_points.size();
            auto [sx, sy] = spawn_points[spawn_index];
            bool accepted = false;

            for (int i = 0; i < max_attempts; ++i) {
                double angle = static_cast<double>(rand()) / RAND_MAX * 2.0 * PI;
                double dist = radius + static_cast<double>(rand()) / RAND_MAX * radius;
                double nx = sx + std::cos(angle) * dist;
                double ny = sy + std::sin(angle) * dist;

                if (is_valid(nx, ny)) {
                    points.emplace_back(nx, ny);
                    spawn_points.emplace_back(nx, ny);

                    int gx = static_cast<int>(nx / cell_size);
                    int gy = static_cast<int>(ny / cell_size);
                    grid[gx + gy * grid_width] = points.size() - 1;

                    accepted = true;
                    break;
                }
            }

            if (!accepted) {
                spawn_points.erase(spawn_points.begin() + spawn_index);
            }
        }

        return points;
    }


    // Returns the angle of point (x, y).
    // Example: math::angle(player.v.x, player.v.y)
    inline double angle(double x, double y) {
        return std::atan2(y, x);
    }

    // Returns the angle from point (x, y) to point (px, py).
// Example: math::angle_to_point(player.x, player.y, enemy.x, enemy.y)
inline double angle_to_point(double x, double y, double px, double py) {
    return std::atan2(py - y, px - x);
}

// Assumes mouse coordinates are available globally or passed as parameters.
// Example: math::angle_to_mouse(player.x, player.y, mouse_x, mouse_y)
inline double angle_to_mouse(double x, double y, double mouse_x, double mouse_y) {
    return std::atan2(mouse_y - y, mouse_x - x);
}

// Returns the angle from the mouse to this point (x, y).
// Example: math::angle_from_mouse(player.x, player.y, mouse_x, mouse_y)
inline double angle_from_mouse(double x, double y, double mouse_x, double mouse_y) {
    return std::atan2(y - mouse_y, x - mouse_x);
}

// Returns the distance from point (x, y) to the mouse.
// Example: math::distance_to_mouse(player.x, player.y, mouse_x, mouse_y)
inline double distance_to_mouse(double x, double y, double mouse_x, double mouse_y) {
    double dx = mouse_x - x;
    double dy = mouse_y - y;
    return std::sqrt(dx * dx + dy * dy);
}

// Linear easing: returns t as is.
inline double linear(double t) {
    return t;
}

Below are the C++ implementations for the specified functions. These use standard mathematical libraries like <cmath> for trigonometric and mathematical operations.
Header Files

#include <cmath>  // For trigonometric functions like atan2, sin, cos, etc.
#include <vector> // For any vector-based operations if needed.

Angle and Distance Calculations
math.angle

// Returns the angle of point (x, y).
// Example: math::angle(player.v.x, player.v.y)
inline double angle(double x, double y) {
    return std::atan2(y, x);
}

math.angle_to_point

// Returns the angle from point (x, y) to point (px, py).
// Example: math::angle_to_point(player.x, player.y, enemy.x, enemy.y)
inline double angle_to_point(double x, double y, double px, double py) {
    return std::atan2(py - y, px - x);
}

math.angle_to_mouse

// Assumes mouse coordinates are available globally or passed as parameters.
// Example: math::angle_to_mouse(player.x, player.y, mouse_x, mouse_y)
inline double angle_to_mouse(double x, double y, double mouse_x, double mouse_y) {
    return std::atan2(mouse_y - y, mouse_x - x);
}

math.angle_from_mouse

// Returns the angle from the mouse to this point (x, y).
// Example: math::angle_from_mouse(player.x, player.y, mouse_x, mouse_y)
inline double angle_from_mouse(double x, double y, double mouse_x, double mouse_y) {
    return std::atan2(y - mouse_y, x - mouse_x);
}

math.distance_to_mouse

// Returns the distance from point (x, y) to the mouse.
// Example: math::distance_to_mouse(player.x, player.y, mouse_x, mouse_y)
inline double distance_to_mouse(double x, double y, double mouse_x, double mouse_y) {
    double dx = mouse_x - x;
    double dy = mouse_y - y;
    return std::sqrt(dx * dx + dy * dy);
}

Easing Functions
Constants

constexpr double PI = 3.141592653589793;
constexpr double PI2 = PI / 2.0;
constexpr double LN2 = std::log(2.0);
constexpr double LN210 = 10.0 * LN2;

math.linear

// Linear easing: returns t as is.
inline double linear(double t) {
    return t;
}

Sine Functions

inline double sine_in(double t) {
    return t == 0 ? 0 : (t == 1 ? 1 : 1 - std::cos(t * PI2));
}

inline double sine_out(double t) {
    return t == 0 ? 0 : (t == 1 ? 1 : std::sin(t * PI2));
}

inline double sine_in_out(double t) {
    return t == 0 ? 0 : (t == 1 ? 1 : -0.5 * (std::cos(t * PI) - 1));
}

inline double sine_out_in(double t) {
    if (t == 0) return 0;
    if (t == 1) return 1;
    return t < 0.5 ? 0.5 * std::sin(2 * t * PI2) : -0.5 * std::cos((2 * t - 1) * PI2) + 1;
}

inline double quad_in(double t) {
    return t * t;
}

inline double quad_out(double t) {
    return -t * (t - 2);
}

inline double quad_in_out(double t) {
    return t < 0.5 ? 2 * t * t : -2 * t * (t - 2) - 1;
}

inline double cubic_in(double t) {
    return t * t * t;
}

inline double cubic_out(double t) {
    t -= 1;
    return t * t * t + 1;
}

inline double cubic_in_out(double t) {
    t *= 2;
    if (t < 1) return 0.5 * t * t * t;
    t -= 2;
    return 0.5 * (t * t * t + 2);
}

inline double quart_in(double t) {
    return t * t * t * t;
}

inline double quart_out(double t) {
    t -= 1;
    return 1 - t * t * t * t;
}

inline double quart_in_out(double t) {
    t *= 2;
    if (t < 1) return 0.5 * t * t * t * t;
    t -= 2;
    return -0.5 * (t * t * t * t - 2);
}

inline double quint_in(double t) {
    return t * t * t * t * t;
}

inline double quint_out(double t) {
    t -= 1;
    return t * t * t * t * t + 1;
}

inline double quint_in_out(double t) {
    t *= 2;
    if (t < 1) return 0.5 * t * t * t * t * t;
    t -= 2;
    return 0.5 * (t * t * t * t * t + 2);
}


} // namespace math

