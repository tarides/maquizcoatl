// client.rs: a pure-Rust client of the Verus and Aeneas prototypes, run
// under Miri (experiment #5, run B; issue #13, "Scheduled follow-ups").
// It plays caller.c's part through the C ABI: during a callout, which
// the verified callout_step makes while it holds a &mut VuArgs, the
// client calls the exported accessors vu_get_slot, vu_set_slot and
// vu_get_subject_byte through the raw pointer it was given
// (re-entrancy shape (b)); and its apply-all function calls back the
// verified vu_i_apply through the C pointer vu_fold_all hands it
// (shape (a)). Miri checks the aliasing of these accesses (Stacked
// Borrows by default, Tree Borrows with -Zmiri-tree-borrows).

use core::ffi::{c_int, c_uint, c_void};
use core::ptr;

use vu::{VuArgs, VuFoldRec};

type CalloutFn = unsafe extern "C" fn(*mut VuArgs, *mut c_void) -> c_int;
type ApplyFn = Option<unsafe extern "C" fn(c_uint, *mut c_uint, c_int, *mut c_void) -> c_int>;
type ApplyAllFn = unsafe extern "C" fn(ApplyFn, *mut c_void) -> c_int;

// The exported functions of proto.h, as a C client sees them.
extern "C" {
    fn vu_callout_step(dir: c_int, f: Option<CalloutFn>, args: *mut VuArgs, ud: *mut c_void) -> c_int;
    fn vu_get_slot(args: *const VuArgs, k: c_int, v: *mut i64) -> c_int;
    fn vu_set_slot(args: *mut VuArgs, k: c_int, v: i64) -> c_int;
    fn vu_get_subject_byte(args: *const VuArgs, i: c_int) -> c_int;
    fn vu_fold_all(g: Option<ApplyAllFn>, rec: *mut VuFoldRec) -> c_int;
}

static SUBJECT: [u8; 3] = *b"abc";

/// Reads slot 0, writes it + 1 into slots 0 and 4, copies the subject's
/// three bytes into slots 1 to 3, probes both accessors out of range,
/// and returns *user_data.
unsafe extern "C" fn co_slots(args: *mut VuArgs, ud: *mut c_void) -> c_int {
    unsafe {
        let mut v: i64 = -1;
        assert_eq!(vu_get_slot(args, 0, &mut v), 0);
        assert_eq!(vu_set_slot(args, 0, v + 1), 0);
        assert_eq!(vu_set_slot(args, 4, v + 1), 0);
        for i in 0..3 {
            let b = vu_get_subject_byte(args, i);
            assert!(b >= 0);
            assert_eq!(vu_set_slot(args, 1 + i, b as i64), 0);
        }
        assert_eq!(vu_get_subject_byte(args, 3), -30);
        assert_eq!(vu_get_subject_byte(args, -1), -30);
        let mut probe: i64 = 12345;
        assert_eq!(vu_get_slot(args, 5, &mut probe), -30);
        assert_eq!(probe, 12345);
        *(ud as *const c_int)
    }
}

/// Calls back the verified function it is given, as caller.c's
/// client_apply_all does, and stops at the first non-zero result.
unsafe extern "C" fn client_apply_all(f: ApplyFn, arg: *mut c_void) -> c_int {
    let f = f.expect("vu_fold_all passes a function");
    let table: [(c_uint, c_int); 4] = [(0x41, 1), (0x61, 1), (0x1e9e, 0), (0x2001, -1)];
    for (from, to_len) in table {
        let mut to: [c_uint; 4] = [0x61, 0, 0, 0];
        let r = unsafe { f(from, to.as_mut_ptr(), to_len, arg) };
        if r != 0 {
            return r;
        }
    }
    0
}

fn main() {
    // Shape (b), in each direction the callout is made.
    for (dir, value, expected) in [(0, 0, 0), (1, 1, 0), (2, 5, 1), (0, 2, -30)] {
        let mut a = VuArgs {
            subject: SUBJECT.as_ptr(),
            subject_len: 3,
            pos: 1,
            num: 1,
            slot: [41, 0, 0, 0, 0],
        };
        let mut value: c_int = value;
        let r = unsafe {
            vu_callout_step(dir, Some(co_slots), &mut a, ptr::addr_of_mut!(value).cast())
        };
        assert_eq!(r, expected);
        assert_eq!(a.slot, [42, 97, 98, 99, 42]);
        assert!(a.subject == SUBJECT.as_ptr() && a.subject_len == 3 && a.pos == 1 && a.num == 1);
        println!("shape (b) dir={dir} callee={value} -> {r} slots={:?}", a.slot);
    }
    // The read accessor with a length shorter than the buffer.
    let a = VuArgs { subject: SUBJECT.as_ptr(), subject_len: 2, pos: 0, num: 0, slot: [0; 5] };
    let got: Vec<c_int> = (0..3).map(|i| unsafe { vu_get_subject_byte(&a, i) }).collect();
    assert_eq!(got, [97, 98, -30]);
    println!("subject_byte len=2 -> {got:?}");
    // Shape (a).
    let mut rec = VuFoldRec { calls: 0, recorded: 0, from: [0; 8] };
    let r = unsafe { vu_fold_all(Some(client_apply_all), &mut rec) };
    assert_eq!((r, rec.calls, rec.recorded), (0, 4, 2));
    assert_eq!(&rec.from[..2], &[0x41, 0x61]);
    println!("shape (a) -> {r} calls={} recorded={} from={:x?}", rec.calls, rec.recorded, &rec.from[..2]);
    println!("miri client: ok");
}
