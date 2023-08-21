use hell_core::error::HellResult;
use wasm_bindgen::JsCast;
use web_sys::DomTokenList;
use crate::{view::EventHandler, console_error};
use crate::error::ErrToWebHellErr;

use super::{Context, ElementTree};

// ----------------------------------------------------------------------------

macro_rules! declare_create_methods {
    ($($fn_name:ident : $enum_name:ident),* $(,)?) => {
        paste::paste! {
            impl Element {
                $(
                    #[inline]
                    pub fn [< create_ $fn_name >] (cx: Context) -> HellResult<Self> {
                        Self::create(cx, ElementVariant::$enum_name)
                    }
                )*
            }
        }
    };
}

// ----------------------------------------------------------------------------

fn create_with<E, F>(cx: Context, f: F) -> HellResult<E>
where E: Into<Element> + Clone,
      F: Fn(ElementHandle<E>) -> HellResult<E>
{
    let id = cx.create_next_element_id();
    let handle = ElementHandle::new(cx, id);
    let element = f(handle)?;
    let _ = cx.add_element(element.clone().into());
    Ok(element)
}

// ----------------------------------------------------------------------------

fn js_array_from_str_slice(val: &[impl AsRef<str>]) -> js_sys::Array {
    let result = js_sys::Array::new_with_length(val.len() as u32);

    for (i, val) in val.iter().enumerate() {
        let js_val = wasm_bindgen::JsValue::from_str(val.as_ref());
        result.set(i as u32, js_val);
    }

    result
}


// ----------------------------------------------------------------------------

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct ElementId(pub usize);

// ----------------------------------------------------------------------------

#[derive(Debug)]
pub struct ElementHandle<E> {
    cx: Context,
    id: ElementId,
    _phantom: std::marker::PhantomData<E>,
}

impl<E> Clone for ElementHandle<E> {
    fn clone(&self) -> Self {
        Self {
            cx: self.cx,
            id: self.id,
            _phantom: std::marker::PhantomData,
        }
    }
}

impl <E> Copy for ElementHandle<E> { }

impl<E> ElementHandle<E> {
    fn from_other<O>(value: ElementHandle<O>) -> Self {
        Self {
            cx: value.cx,
            id: value.id,
            _phantom: std::marker::PhantomData,
        }
    }
}

impl<E> ElementHandle<E> {
    #[inline]
    pub fn new(cx: Context, id: ElementId) -> Self {
        Self { cx, id, _phantom: std::marker::PhantomData }
    }

    #[inline]
    pub fn get(&self) -> E
    where E: From<Element>
    {
        E::from(
            self.cx.get_element(self.id)
        )
    }

    #[inline]
    pub fn get_all(self) -> (ElementHandle<E>, E)
    where E: From<Element>
    {
        (
            self,
            E::from(self.cx.get_element(self.id))
        )
    }
}

// ----------------------------------------------------------------------------

#[derive(Debug, Clone, Copy)]
pub enum ElementVariant {
    Button,
    Div,
    Html,
    H1,
    H2,
    H3,
    H4,
    Invalid,
    Input,
    Header,
    Main,
    Footer,
    Paragraph,
    Style,
    Span,
}

impl ElementVariant {
    pub fn tag_name(&self) -> &'static str {
        match self {
            ElementVariant::Invalid   |
            ElementVariant::Html      =>
                panic!("trying to get tag-name for an invalid ElementVariant"),
            ElementVariant::Button    => "button",
            ElementVariant::Div       => "div",
            ElementVariant::H1        => "h1",
            ElementVariant::H2        => "h2",
            ElementVariant::H3        => "h3",
            ElementVariant::H4        => "h4",
            ElementVariant::Input     => "input",
            ElementVariant::Main      => "main",
            ElementVariant::Paragraph => "p",
            ElementVariant::Span      => "span",
            ElementVariant::Style     => "style",
            ElementVariant::Header    => "header",
            ElementVariant::Footer    => "footer",
        }
    }
}

// ----------------------------------------------------------------------------

#[derive(Debug)]
pub struct Element {
    handle: ElementHandle<Self>,
    js_element: web_sys::Element,
}

impl Clone for Element {
    fn clone(&self) -> Self {
        Self {
            handle: self.handle,
            js_element: self.js_element.clone()
        }
    }
}

impl Element {
    pub fn to_html(self) -> HtmlElement {
        HtmlElement::from(self)
    }

    pub fn to_input(self) -> HtmlInputElement {
        HtmlInputElement::from(self)
    }
}

impl Element {
    pub fn new(cx: Context, handle: ElementHandle<Self>, variant: ElementVariant) -> HellResult<Self> {
        let name = variant.tag_name();
        let js_element: web_sys::Element = cx.document().create_element(name).to_web_hell_err()?;

        Ok(Self {
            handle,
            js_element,
        })
    }

    pub fn create(cx: Context, variant: ElementVariant) -> HellResult<Self> {
        let id = cx.create_next_element_id();
        let handle = ElementHandle::new(cx, id);
        let element = Element::new(cx, handle, variant)?;
        let _ = cx.add_element(element.clone());
        Ok(element)
    }

    pub fn as_input_element(&self) -> HellResult<web_sys::HtmlInputElement> {
        Ok(self.js_element().clone().dyn_into::<web_sys::HtmlInputElement>().unwrap())
    }

    // pub fn create_html(cx: Context) -> HellResult<ElementHandle<HtmlElement>> {
    //     create_with(cx, |handle| {
    //         HtmlElement::new(cx, handle)
    //     })
    // }

    pub fn create_html(cx: Context) -> HellResult<HtmlElement> {
        create_with(cx, |handle| {
            Ok(HtmlElement {
                handle,
                js_element: cx.document().query_selector("html").to_web_hell_err().map_err(|e| {
                    console_error!("failed to get html element: {:?}", e);
                    e
                })?
                    .expect("expected there to be a html element")
                    .dyn_into::<web_sys::HtmlElement>().unwrap()
            })
        })
    }

    pub fn create_body(cx: Context) -> HellResult<HtmlElement> {
        create_with(cx, |handle| {
            Ok(HtmlElement {
                handle,
                js_element: cx.document().body().expect("expected there to be a body")
            })
        })
    }

    pub fn create_input(cx: Context) -> HellResult<HtmlInputElement> {
        create_with(cx, |handle| {
            HtmlInputElement::new(cx, handle)
        })
    }

    pub fn create_button(cx: Context) -> HellResult<HtmlButtonElement> {
        create_with(cx, |handle| {
            HtmlButtonElement::new(cx, handle)
        })
    }
}



declare_create_methods! {
    div: Div,
    paragraph: Paragraph,
    span: Span,
    style: Style,
    h1: H1,
    h2: H2,
    h3: H3,
    h4: H4,
    main: Main,
    header: Header,
    footer: Footer,
}

impl ElementContainer for Element {
    fn handle(&self) -> ElementHandle<Self> {
        self.handle
    }

    fn js_element(&self) -> &web_sys::Element {
        self.js_element.as_ref()
    }
}

impl<E> ElementTree for E where E: ElementContainer + 'static {
    fn root(&self) -> &web_sys::Element  {
        self.js_element()
    }
}


pub trait ElementContainer: Clone {
    fn js_element(&self) -> &web_sys::Element;
    fn handle(&self) -> ElementHandle<Self>;

    fn with_handle(self) -> (Self, ElementHandle<Self>) {
        let handle = self.handle();
        (self, handle)
    }

    fn append_child<E>(&mut self, tree: &E) -> HellResult<()>
    where E: ElementTree
    {
        let _ = self.js_element().append_child(tree.root()).to_web_hell_err().map_err(|e| {
            console_error!("failed to append child: {:?}", e);
            e
        });
        Ok(())
    }

    fn append_child_unchecked<E>(&mut self, tree: &E)
    where E: ElementTree
    {
        self.append_child(tree).unwrap()
    }


    // content operations
    // ------------------

    #[inline]
    fn inner_html(&self) -> String {
        self.js_element().inner_html()
    }

    #[inline]
    fn set_inner_html(&mut self, value: &str) {
        self.js_element().set_inner_html(value);
    }

    #[inline]
    fn text_content(&self) -> Option<String> {
        self.js_element().text_content()
    }

    #[inline]
    fn set_text_content(&mut self, value: Option<&str>) {
        self.js_element().set_text_content(value);
    }

    fn with_text_content(mut self, value: Option<&str>) -> Self {
        self.set_text_content(value);
        self
    }

    // id operations
    // -------------
    fn id(&self) -> String {
        self.js_element().id()
    }

    fn set_id(&mut self, value: impl AsRef<str>) {
        self.js_element().set_id(value.as_ref())
    }

    // class operations
    // ----------------
    fn class_list(&self) -> DomTokenList {
        self.js_element().class_list()
    }

    fn class_name(&self) -> String {
        self.js_element().class_name()
    }

    fn add_class(&mut self, name: impl AsRef<str>) -> HellResult<()> {
        let classes = self.js_element().class_list();
        classes.add_1(name.as_ref()).to_web_hell_err().map_err(|e| {
            console_error!("failed to add class: {:?}", e);
            e
        })
    }

    #[inline]
    fn add_class_uncheckd(&mut self, name: impl AsRef<str>) {
        self.add_class(name).expect("failed to add single class");
    }

    fn with_class(mut self, name: impl AsRef<str>) -> HellResult<Self> {
        self.add_class(name)?;
        Ok(self)
    }

    fn add_classes(&mut self, names: &[impl AsRef<str>]) -> HellResult<()> {
        let classes = self.js_element().class_list();
        let names = js_array_from_str_slice(names);
        classes.add(&names).to_web_hell_err().map_err(|e| {
            console_error!("failed to add classes: {:?}", e);
            e
        })
    }

    fn with_classes(mut self, names: &[impl AsRef<str>]) -> HellResult<Self> {
        self.add_classes(names)?;
        Ok(self)
    }

    #[inline]
    fn add_classes_unchecked(&mut self, names: &[&str]) {
        self.add_classes(names).expect("failed to add multiple classes");
    }

    fn remove_class(&mut self, name: &str) -> HellResult<()> {
        let classes = self.js_element().class_list();
        classes.remove_1(name).to_web_hell_err().map_err(|e| {
            console_error!("failed to remove class: {:?}", e);
            e
        })
    }

    fn remove_classes(&mut self, names: &[&str]) -> HellResult<()> {
        let classes = self.js_element().class_list();
        let names = js_array_from_str_slice(names);
        classes.remove(&names).to_web_hell_err().map_err(|e| {
            console_error!("failed to remove classes: {:?}", e);
            e
        })
    }

    fn contains_class(&mut self, name: &str) -> bool {
        let classes = self.js_element().class_list();
        classes.contains(name)
    }

    // attribute operations
    // --------------------
    #[inline]
    fn set_attribute(&mut self, name: &str, value: &str) -> HellResult<()> {
        self.js_element().set_attribute(name, value).to_web_hell_err().map_err(|e| {
            console_error!("failed to set attribute: {:?}", e);
            e
        })
    }

    fn set_attributes(&mut self, attributes: &[(&str, &str)]) -> HellResult<()> {
        for (name, value) in attributes {
            self.js_element().set_attribute(name, value).to_web_hell_err().map_err(|e| {
                console_error!("failed to set attribute: {:?}", e);
                e
            })?;
        }

        Ok(())
    }

    fn with_attributes(mut self, attributes: &[(&str, &str)]) -> HellResult<Self> {
        self.set_attributes(attributes)?;
        Ok(self)
    }

    #[inline]
    fn get_attribute(&mut self, name: &str) -> Option<String> {
        self.js_element().get_attribute(name)
    }

    #[inline]
    fn has_attribute(&mut self, name: &str) -> bool {
        self.js_element().has_attribute(name)
    }

    // event operations
    // ----------------
    fn add_event_listener<C>(&self, event_type: &'static str, cb: C) -> HellResult<()>
    where C: FnMut(web_sys::Event) + 'static
    {
        let handle = self.handle();
        let event_handler = EventHandler::from_event(self.js_element(), event_type, cb)?;
        handle.cx.add_event_handler(handle.id, event_type, event_handler);
        Ok(())
    }

    // pub fn remove_event_listener(&mut self, event_type: &'static str) -> HellResult<()> {
    //     let listener = self.events.remove(event_type).expect("expected handler in event-map");
    //     self
    //         .inner()
    //         .remove_event_listener_with_callback(event_type, &listener.closure_function())
    //         .to_web_hell_err()
    // }
}

// ----------------------------------------------------------------------------

#[derive(Clone)]
pub struct HtmlElement {
    handle: ElementHandle<Self>,
    js_element: web_sys::HtmlElement,
}

impl From<Element> for HtmlElement {
    fn from(element: Element) -> Self {
        Self {
            handle: ElementHandle::from_other(element.handle()),
            js_element: element.js_element.dyn_into().unwrap(),
        }
    }
}

impl From<HtmlElement> for Element {
    fn from(value: HtmlElement) -> Self {
        let handle = ElementHandle {
            cx: value.handle.cx,
            id: value.handle.id,
            _phantom: std::marker::PhantomData,
        };
        Self {
            handle,
            js_element: value.js_element.dyn_into().unwrap(),
        }
    }
}

impl HtmlElement {
    pub fn new(cx: Context, handle: ElementHandle<Self>) -> HellResult<Self> {
        let variant = ElementVariant::Input;
        let js_element: web_sys::HtmlElement = cx.document()
            .create_element(variant.tag_name())
            .unwrap()
            .dyn_into()
            .unwrap();

        Ok(Self {
            handle,
            js_element,
        })
    }
}

impl ElementContainer for HtmlElement {
    fn handle(&self) -> ElementHandle<Self> {
        self.handle
    }

    fn js_element(&self) -> &web_sys::Element {
        &self.js_element
    }
}

// ----------------------------------------------------------------------------

#[derive(Clone)]
pub struct HtmlInputElement {
    handle: ElementHandle<Self>,
    js_element: web_sys::HtmlInputElement,
}

impl From<Element> for HtmlInputElement {
    fn from(element: Element) -> Self {
        Self {
            handle: ElementHandle::from_other(element.handle()),
            js_element: element.js_element.dyn_into().unwrap(),
        }
    }
}

impl From<HtmlInputElement> for Element {
    fn from(value: HtmlInputElement) -> Self {
        Self {
            handle: ElementHandle::from_other(value.handle()),
            js_element: value.js_element.dyn_into().unwrap(),
        }
    }
}

impl ElementContainer for HtmlInputElement {
    fn handle(&self) -> ElementHandle<Self> {
        self.handle
    }

    fn js_element(&self) -> &web_sys::Element {
        &self.js_element
    }
}

impl HtmlInputElement {
    pub fn new(cx: Context, handle: ElementHandle<Self>) -> HellResult<Self> {
        let variant = ElementVariant::Input;
        let js_element: web_sys::HtmlInputElement = cx.document()
            .create_element(variant.tag_name())
            .unwrap()
            .dyn_into()
            .unwrap();

        Ok(Self {
            handle,
            js_element,
        })
    }

    pub fn value(&self) -> String {
        self.js_element.value()
    }

    pub fn set_value(&mut self, value: &str) {
        self.js_element.set_value(value);
    }
}

// ----------------------------------------------------------------------------

#[derive(Clone)]
pub struct HtmlButtonElement {
    handle: ElementHandle<Self>,
    js_element: web_sys::HtmlButtonElement,
}

impl From<Element> for HtmlButtonElement {
    fn from(value: Element) -> Self {
        Self {
            handle: ElementHandle::from_other(value.handle()),
            js_element: value.js_element.dyn_into().unwrap(),
        }
    }
}

impl From<HtmlButtonElement> for Element {
    fn from(value: HtmlButtonElement) -> Self {
        Self {
            handle: ElementHandle::from_other(value.handle()),
            js_element: value.js_element.dyn_into().unwrap(),
        }
    }
}

impl ElementContainer for HtmlButtonElement {
    fn handle(&self) -> ElementHandle<Self> {
        self.handle.clone()
    }

    fn js_element(&self) -> &web_sys::Element {
        &self.js_element
    }
}

impl HtmlButtonElement {
    pub fn new(cx: Context, handle: ElementHandle<Self>) -> HellResult<Self> {
        let variant = ElementVariant::Button;
        let js_element: web_sys::HtmlButtonElement = cx.document()
            .create_element(variant.tag_name())
            .unwrap()
            .dyn_into()
            .unwrap();

        Ok(Self {
            handle,
            js_element,
        })
    }

    pub fn click(&self) {
        self.js_element.click();
    }

    pub fn set_disable(&mut self, value: bool) {
        self.js_element.set_disabled(value)
    }

    pub fn disable(&mut self) -> bool {
        self.js_element.disabled()
    }
}

