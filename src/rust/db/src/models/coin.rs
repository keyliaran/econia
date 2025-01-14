use diesel::prelude::*;

use crate::schema::coins;

use super::ToInsertable;

#[derive(Clone, Debug, Queryable, Identifiable)]
#[diesel(table_name = coins, primary_key(account_address, module_name, struct_name))]
pub struct Coin {
    pub account_address: String,
    pub module_name: String,
    pub struct_name: String,
    pub symbol: String,
    pub name: String,
    pub decimals: i16,
}

impl From<Coin> for types::Coin {
    fn from(value: Coin) -> Self {
        Self {
            account_address: value.account_address,
            module_name: value.module_name,
            struct_name: value.struct_name,
            symbol: value.symbol,
            name: value.name,
            decimals: value.decimals,
        }
    }
}

#[derive(Insertable, Debug, AsChangeset)]
#[diesel(table_name = coins, primary_key(account_address, module_name, struct_name))]
pub struct NewCoin<'a> {
    pub account_address: &'a str,
    pub module_name: &'a str,
    pub struct_name: &'a str,
    pub symbol: &'a str,
    pub name: &'a str,
    pub decimals: i16,
}

impl ToInsertable for Coin {
    type Insertable<'a> = NewCoin<'a>;

    fn to_insertable(&self) -> Self::Insertable<'_> {
        NewCoin {
            account_address: &self.account_address,
            module_name: &self.module_name,
            struct_name: &self.struct_name,
            symbol: &self.symbol,
            name: &self.name,
            decimals: self.decimals,
        }
    }
}
