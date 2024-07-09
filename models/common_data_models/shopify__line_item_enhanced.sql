with line_items as (

    select * 
    from {{ var('shopify_order_line')}}

), orders as ( 

    select * 
    from {{ var('shopify_order')}}

), product as (

    select *
    from {{ var('shopify_product')}}

), transactions as (

    select *
    from {{ var('shopify_transaction')}}
    where kind = 'capture'

), refund_transactions as (

    select
        order_id,
        source_relation,
        sum(amount) as total_order_refund_amount
    from {{ var('shopify_transaction')}}
    where kind = 'refund' 
    group by 1, 2

), order_line_refund as (

    select *
    from {{ var('shopify_order_line_refund')}}

), customer as (

    select *
    from {{ var('shopify_customer')}}

), enhanced as (

    select
        li.order_id as header_id,
        li.order_line_id as line_item_id,
        li.index as line_item_index,
        o.created_timestamp as created_at,
        o.currency as currency,
        o.fulfillment_status as header_status,
        li.product_id as product_id,
        p.title as product_name,
        t.kind as transaction_type,
        null as billing_type,
        p.product_type as product_type,
        li.quantity as quantity,
        li.price as unit_amount,
        li.total_discount as discount_amount,
        o.total_tax as tax_amount,
        (li.quantity * li.price) as total_amount,  
        t.transaction_id as payment_id,
        null as payment_method_id,
        t.gateway as payment_method, -- payment_method in tender_transaction would be like 'apply_pay', where gateway is like 'gift card' or 'shopify payments' which i think is more relevant here
        t.processed_timestamp as payment_at,
        null as fee_amount,
        rt.total_order_refund_amount as refund_amount,
        null as subscription_id,
        null as subscription_period_started_at,
        null as subscription_period_ended_at,
        null as subscription_status,
        o.customer_id,
        'customer' as customer_level,
        {{ dbt.concat(["c.first_name", "''", "c.last_name"]) }} as customer_name,
        o.shipping_address_company as customer_company,
        o.email as customer_email,
        o.shipping_address_city as customer_city,
        o.shipping_address_country as customer_country,
        li.source_relation
    from line_items li
    left join orders o
        on li.order_id = o.order_id
        and li.source_relation = o.source_relation
    left join transactions t
        on o.order_id = t.order_id
        and o.source_relation = t.source_relation
    left join refund_transactions rt
        on o.order_id = rt.order_id
        and o.source_relation = rt.source_relation
    left join order_line_refund olr
        on li.order_line_id = olr.order_line_id
        and li.source_relation = olr.source_relation
    left join product p 
        on li.product_id = p.product_id
        and li.source_relation = p.source_relation
    left join customer c
        on o.customer_id = c.customer_id
        and o.source_relation = c.source_relation
        
), final as (

    select 
        header_id,
        cast(line_item_id as {{ dbt.type_numeric() }}) as line_item_id,
        cast(line_item_index as {{ dbt.type_numeric() }}) as line_item_index,
        'line_item' as record_type,
        created_at,
        currency,
        header_status,
        billing_type,
        cast(product_id as {{ dbt.type_numeric() }}) as product_id,
        product_name,
        product_type,
        cast(quantity as {{ dbt.type_numeric() }}) as quantity,
        cast(unit_amount as {{ dbt.type_numeric() }}) as unit_amount,
        cast(null as {{ dbt.type_numeric() }}) as discount_amount,
        cast(null as {{ dbt.type_numeric() }}) as tax_amount,
        cast(total_amount as {{ dbt.type_numeric() }}) as total_amount,
        payment_id,
        payment_method_id,
        payment_method,
        payment_at,
        fee_amount,
        cast(null as {{ dbt.type_numeric() }}) as refund_amount,
        subscription_id,
        subscription_period_started_at,
        subscription_period_ended_at,
        subscription_status,
        customer_id,
        customer_level,
        customer_name,
        customer_company,
        customer_email,
        customer_city,
        customer_country,
        source_relation
    from enhanced

    union all

    select 
        header_id,
        cast(null as {{ dbt.type_numeric() }}) as line_item_id,
        cast(0 as {{ dbt.type_numeric() }}) as line_item_index,
        'header' as record_type,
        created_at,
        currency,
        header_status,
        billing_type,
        cast(null as {{ dbt.type_numeric() }}) as product_id,
        cast(null as {{ dbt.type_string() }}) as product_name,
        cast(null as {{ dbt.type_string() }}) as product_type,
        cast(null as {{ dbt.type_numeric() }}) as quantity,
        cast(null as {{ dbt.type_numeric() }}) as unit_amount,
        discount_amount,
        tax_amount,
        cast(null as {{ dbt.type_numeric() }}) as total_amount,
        payment_id,
        payment_method_id,
        payment_method,
        payment_at,
        fee_amount,
        refund_amount,
        subscription_id,
        subscription_period_started_at,
        subscription_period_ended_at,
        subscription_status,
        customer_id,
        customer_level,
        customer_name,
        customer_company,
        customer_email,
        customer_city,
        customer_country,
        source_relation
    from enhanced
    where line_item_index = 1 -- filter to just one arbitrary record

)

select * 
from final
order by header_id, line_item_index asc, source_relation