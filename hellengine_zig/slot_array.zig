const assert = @import("std").debug.assert;

pub fn SlotArray(comptime T: type, comptime array_capacity: usize) type {
    return struct {
        const Self = @This();
        const capacity = array_capacity;

        items_raw: [capacity]T    = undefined,
        is_free:   [capacity]bool = [_]bool { true } ** capacity,

        fn find_first_free_slot(self: *const Self) usize {
            var idx: usize = 0;

            for (self.is_free) |is_free| {
                if (is_free) { break; }
                idx += 1;
            }

            return idx;
        }

        pub fn add(self: *Self, value: T) usize {
            const free_slot = self.find_first_free_slot();
            assert(free_slot < capacity);

            self.is_free[free_slot] = false;
            self.items_raw[free_slot] = value;

            return free_slot;
        }

        pub fn remove(self: *Self, idx: usize) void {
            assert(!self.is_free[idx]);
            self.is_free[idx] = true;
        }

        pub fn get(self: *const Self, idx: usize) T {
            assert(!self.is_free[idx]);
            return self.items_raw[idx];
        }

        pub fn get_ref(self: *const Self, idx: usize) *const T {
            assert(!self.is_free[idx]);
            return &self.items_raw[idx];
        }

        pub fn get_mut(self: *Self, idx: usize) *T {
            assert(!self.is_free[idx]);
            return &self.items_raw[idx];
        }

        pub fn to_string(self: *const Self) [capacity*2]u8 {
            var result: [capacity*2]u8 = undefined;
            for (0..(capacity / 2)) |idx| {
                result[idx * 2 + 0] = if (self.is_free[idx]) 'F' else 'o';
                result[idx * 2 + 1] = ';';
            }
            return result;
        }
    };
}

