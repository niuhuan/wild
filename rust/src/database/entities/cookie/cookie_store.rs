use crate::database::entities::cookie::cookie::ActiveModel;
use crate::database::entities::cookie::cookie::Column;
use crate::database::entities::cookie::cookie::Entity;
use crate::database::entities::CookieEntity;
use bytes::Bytes;
use reqwest::cookie::CookieStore;
use reqwest::header::HeaderValue;
use reqwest::Url;
use sea_orm::{ActiveModelTrait, ColumnTrait, EntityTrait, QueryFilter};
use std::ops::Deref;

pub struct DatabaseCookieStore {}

impl DatabaseCookieStore {
    async fn save_cookie(&self, cookie: &::cookie::Cookie<'_>, url: &Url) -> anyhow::Result<()> {
        let domain = cookie
            .domain()
            .unwrap_or_else(|| url.host_str().unwrap())
            .to_string();
        let path = cookie.path().unwrap_or("/").to_string();
        let expires = cookie
            .expires()
            .map(|e| e.datetime().map(|e| e.unix_timestamp()));

        let model = crate::database::entities::Cookie {
            domain,
            name: cookie.name().to_string(),
            value: cookie.value().to_string(),
            path,
            expires: expires.unwrap_or(None),
            secure: cookie.secure(),
            http_only: cookie.http_only(),
        };

        CookieEntity::save_or_update_cookie(model).await?;
        Ok(())
    }

    async fn load_cookies(&self, url: &Url) -> anyhow::Result<Vec<::cookie::Cookie>> {
        let host = url.host_str().unwrap();
        let cookies = CookieEntity::find_by_domain(host).await?;
        let cookies = cookies
            .into_iter()
            .map(|e| ::cookie::Cookie::new(e.name, e.value))
            .collect();
        Ok(cookies)
    }
}

#[async_trait::async_trait]
impl CookieStore for DatabaseCookieStore {
    fn set_cookies(&self, cookie_headers: &mut dyn Iterator<Item = &HeaderValue>, url: &Url) {
        for header in cookie_headers {
            if let Ok(cookie) = ::cookie::Cookie::parse(header.to_str().unwrap()) {
                let _ = tokio::task::block_in_place(|| {
                    tokio::runtime::Handle::current()
                        .block_on(async move { self.save_cookie(&cookie, &url).await })
                });
            }
        }
    }

    fn cookies(&self, url: &Url) -> Option<HeaderValue> {
        if let Ok(cookies) = tokio::task::block_in_place(|| {
            tokio::runtime::Handle::current().block_on(async move { self.load_cookies(url).await })
        }) {
            let cookies: Vec<_> = cookies.into_iter().collect();
            let s = cookies
                .into_iter()
                .map(|c| format!("{}={}", c.name(), c.value()))
                .collect::<Vec<_>>()
                .join("; ");

            if s.is_empty() {
                return None;
            }

            HeaderValue::from_maybe_shared(Bytes::from(s)).ok()
        } else {
            None
        }
    }
}
