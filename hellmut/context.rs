use std::{cell::{RefCell, Cell}, any::Any, marker::PhantomData, collections::{HashMap, HashSet}, fmt::Display};
use crate::console_debug;
use super::{EventHandler, EventHandlerId, ElementId, Element};

pub type InnerSignalValue = Box<dyn Any>;
pub type InnerEffect      = Box<(dyn Fn() + 'static)>;

pub struct InnerContext {
    window:   web_sys::Window,
    document: web_sys::Document,

    signal_values: RefCell<Vec<InnerSignalValue>>,
    signal_subscribers: RefCell<HashMap<SignalId, HashSet<EffectId>>>,

    effects: RefCell<Vec<InnerEffect>>,
    running_effect: Cell<Option<EffectId>>,

    elements: RefCell<Vec<Element>>,
    element_event_handlers: RefCell<HashMap<ElementId, HashMap<&'static str, EventHandler>>>,
}

impl InnerContext {
    pub fn new() -> Self {
        let window = web_sys::window().expect("no global window exists");
        let document = window.document().expect("should have a document on window");

        let signals = RefCell::new(Vec::new());
        let signal_subscribers = RefCell::new(HashMap::new());
        let effects = RefCell::new(Vec::new());
        let running_effect = Cell::new(None);
        let elements = RefCell::new(Vec::new());
        let element_event_handlers = RefCell::new(HashMap::new());

        Self {
            window,
            document,

            signal_values: signals,
            signal_subscribers,
            effects,
            running_effect,
            elements,
            element_event_handlers,
        }
    }
}

// ----------------------------------------------------------------------------

#[derive(Clone, Copy)]
pub struct Context {
    inner: &'static InnerContext,
}

impl std::fmt::Debug for Context {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("Runtime").finish()
    }
}

impl Context {
    pub fn new() -> Self {
        let inner = Box::leak(Box::new(InnerContext::new()));
        Self { inner }
    }

    // ...

    pub fn create_signal<T>(&self, val: T) -> Signal<T>
    where T: Clone +'static
    {
        console_debug!("[SIGNAL]: start creating ...");

        let mut signals = self.inner.signal_values.borrow_mut();
        signals.push(Box::new(val));
        let signal_id = SignalId(signals.len() - 1);

        console_debug!("[SIGNAL]: created {}", signal_id.0);

        Signal {
            cx: *self,
            id: signal_id,
            _t: PhantomData,
        }
    }

    // ...

    pub fn create_effect(&self, effect: impl Fn() + 'static) -> EffectId {
        console_debug!("[EFFECT]: start creating");

        let effect_id = {
            let mut effects = self.inner.effects.borrow_mut();
            effects.push(Box::new(effect));
            EffectId(effects.len() - 1)
        };

        self.run_effect(effect_id);

        console_debug!("[EFFECT]: created: '{}'", effect_id);

        effect_id
    }

    fn run_effect(&self, effect_id: EffectId) {
        let prev_effect = self.inner.running_effect.take();
        self.inner.running_effect.set(Some(effect_id));

        console_debug!("[EFFECT]: run: '{}'", effect_id);
        let effect = &self.effects().borrow()[effect_id.0];
        effect();

        self.inner.running_effect.set(prev_effect);
    }

    // ...
}

// ----------------------------------------------

#[derive(Debug)]
pub struct Signal<T> {
    cx: Context,
    id: SignalId,
    _t: PhantomData<T>
}

impl<T> Clone for Signal<T> {
    fn clone(&self) -> Self {
        Self {
            cx: self.cx,
            id: self.id,
            _t: PhantomData,
        }
    }
}

impl<T> Copy for Signal<T> {}

impl<T> Signal<T> {
    pub fn get(&self) -> T
    where T: Clone + 'static
    {
        console_debug!("[SIGNAL]: get: '{}'", self.id);

        let value = self.cx.signal_values()
            .borrow()[self.id.0]
            .downcast_ref::<T>()
            .unwrap()
            .clone();

        self.try_add_sub();

        value
    }

    pub fn set(&self, val: T)
    where T: 'static
    {
        console_debug!("[SIGNAL]: set: '{}'", self.id);

        {
            let wrapper = &mut self.cx.signal_values().borrow_mut()[self.id.0];
            let wrapper = wrapper.downcast_mut::<T>().unwrap();
            *wrapper = val;
        }

        self.run_effects_on_subs();
    }

    pub fn with_ref<C>(&self, mut cb: C)
    where T: 'static,
          C: FnMut(&T),
    {
        console_debug!("[SIGNAL]: with: '{}'", self.id);
        self.try_add_sub();

        {
            let wrapper = &mut self.cx.signal_values().borrow_mut()[self.id.0];
            let wrapper = wrapper.downcast_ref::<T>().unwrap();
            cb(wrapper);
        }
    }

    pub fn with_mut<C>(&self, mut cb: C)
    where T: 'static,
          C: FnMut(&mut T),
    {
        console_debug!("[SIGNAL]: with_mut: '{}'", self.id);
        self.try_add_sub();

        {
            let wrapper = &mut self.cx.signal_values().borrow_mut()[self.id.0];
            let wrapper = wrapper.downcast_mut::<T>().unwrap();
            cb(wrapper);
        }

        self.run_effects_on_subs();
    }
}

impl<T> Signal<T> {
    fn try_add_sub(&self) {
        console_debug!("try add sub: '{}''", self.id);

        if let Some(running_effect_id) = self.cx.inner.running_effect.get() {
            console_debug!("add sub: '{}' - '{}'", self.id, running_effect_id);
            let mut subs = self.cx.inner.signal_subscribers.borrow_mut();
            let subs = subs.entry(self.id).or_default();
            let _newly_inserted = subs.insert(running_effect_id);
        }
    }

    fn run_effects_on_subs(&self) {
        let subs = {
            let subs = self.cx.inner.signal_subscribers.borrow();
            subs.get(&self.id).cloned()
        };

        console_debug!("[SIGNAL]: run_effects_on_subs: '{}'", self.id);

        if let Some(subs) = subs {
            if let Some(running_effect) = self.cx.inner.running_effect.get() {
                for s in subs.into_iter().filter(|s| *s != running_effect) {
                    self.cx.run_effect(s);
                }
            } else {
                for s in subs {
                    self.cx.run_effect(s);
                }
            };
        }
    }
}
