--
-- PostgreSQL database dump
--

\restrict GIfUOQVAtZ5htBjr9wWviyY69kRoqnrKOo9wB6FOodHaMpJQhqItJJEqjSGlps7

-- Dumped from database version 18.6 (Debian 18.6-1.pgdg12+2)
-- Dumped by pg_dump version 18.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: homefix_db_wuc1_user
--

-- *not* creating schema, since initdb creates it


ALTER SCHEMA public OWNER TO homefix_db_wuc1_user;

--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: update_technician_rating(); Type: FUNCTION; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE FUNCTION public.update_technician_rating() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE technicians
    SET rating_count = rating_count + 1,
        rating_avg = ((rating_avg * rating_count) + NEW.rating) / (rating_count + 1),
        updated_at = now()
    WHERE id = NEW.technician_id;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_technician_rating() OWNER TO homefix_db_wuc1_user;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: addresses; Type: TABLE; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE TABLE public.addresses (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    user_id uuid NOT NULL,
    label character varying(50),
    line1 character varying(255) NOT NULL,
    line2 character varying(255),
    city character varying(100) NOT NULL,
    state character varying(100) NOT NULL,
    pincode character varying(10) NOT NULL,
    latitude double precision,
    longitude double precision,
    is_default boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.addresses OWNER TO homefix_db_wuc1_user;

--
-- Name: ai_diagnosis_messages; Type: TABLE; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE TABLE public.ai_diagnosis_messages (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    session_id uuid NOT NULL,
    role character varying(10) NOT NULL,
    content text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.ai_diagnosis_messages OWNER TO homefix_db_wuc1_user;

--
-- Name: ai_diagnosis_sessions; Type: TABLE; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE TABLE public.ai_diagnosis_sessions (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    user_id uuid NOT NULL,
    booking_id uuid,
    category_id uuid,
    status character varying(20) DEFAULT 'active'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.ai_diagnosis_sessions OWNER TO homefix_db_wuc1_user;

--
-- Name: audit_logs; Type: TABLE; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE TABLE public.audit_logs (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    admin_user_id uuid NOT NULL,
    action character varying(100) NOT NULL,
    entity_type character varying(50) NOT NULL,
    entity_id character varying(100),
    details jsonb,
    ip_address character varying(64),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.audit_logs OWNER TO homefix_db_wuc1_user;

--
-- Name: booking_estimate_items; Type: TABLE; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE TABLE public.booking_estimate_items (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    estimate_id uuid NOT NULL,
    item_type character varying(10) NOT NULL,
    name character varying(200) NOT NULL,
    quantity numeric(10,2) DEFAULT 1 NOT NULL,
    unit_price numeric(10,2) DEFAULT 0 NOT NULL,
    amount numeric(10,2) DEFAULT 0 NOT NULL
);


ALTER TABLE public.booking_estimate_items OWNER TO homefix_db_wuc1_user;

--
-- Name: booking_estimates; Type: TABLE; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE TABLE public.booking_estimates (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    booking_id uuid NOT NULL,
    technician_id uuid NOT NULL,
    status character varying(20) DEFAULT 'pending'::character varying NOT NULL,
    labour_amount numeric(10,2) DEFAULT 0 NOT NULL,
    parts_amount numeric(10,2) DEFAULT 0 NOT NULL,
    total_amount numeric(10,2) DEFAULT 0 NOT NULL,
    note text,
    customer_note text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    decided_at timestamp with time zone,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.booking_estimates OWNER TO homefix_db_wuc1_user;

--
-- Name: booking_job_photos; Type: TABLE; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE TABLE public.booking_job_photos (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    booking_id uuid NOT NULL,
    technician_id uuid NOT NULL,
    photo_type character varying(10) NOT NULL,
    image_url text NOT NULL,
    caption text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.booking_job_photos OWNER TO homefix_db_wuc1_user;

--
-- Name: booking_messages; Type: TABLE; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE TABLE public.booking_messages (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    booking_id uuid NOT NULL,
    sender_id uuid NOT NULL,
    sender_role character varying(20) NOT NULL,
    content text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.booking_messages OWNER TO homefix_db_wuc1_user;

--
-- Name: booking_service_seq; Type: SEQUENCE; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE SEQUENCE public.booking_service_seq
    START WITH 1000
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.booking_service_seq OWNER TO homefix_db_wuc1_user;

--
-- Name: booking_status_history; Type: TABLE; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE TABLE public.booking_status_history (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    booking_id uuid NOT NULL,
    status character varying(30) NOT NULL,
    note text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.booking_status_history OWNER TO homefix_db_wuc1_user;

--
-- Name: bookings; Type: TABLE; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE TABLE public.bookings (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    customer_id uuid NOT NULL,
    technician_id uuid,
    category_id uuid NOT NULL,
    address_id uuid NOT NULL,
    status character varying(30) DEFAULT 'requested'::character varying NOT NULL,
    problem_description text,
    scheduled_at timestamp with time zone,
    estimated_price numeric(10,2),
    final_price numeric(10,2),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    notes text,
    images text[] DEFAULT '{}'::text[],
    payment_status character varying(20) DEFAULT 'pending'::character varying NOT NULL,
    service_code character varying(20) DEFAULT ('SRV-'::text || lpad((nextval('public.booking_service_seq'::regclass))::text, 6, '0'::text)) NOT NULL,
    otp_code character varying(6),
    otp_verified_at timestamp without time zone,
    warranty_enabled boolean DEFAULT false NOT NULL,
    warranty_days integer,
    warranty_expires_at timestamp with time zone,
    is_warranty_claim boolean DEFAULT false NOT NULL,
    warranty_claim_of uuid,
    visit_fee_amount numeric(10,2),
    visit_fee_status character varying(20),
    visit_fee_charged boolean DEFAULT false NOT NULL
);


ALTER TABLE public.bookings OWNER TO homefix_db_wuc1_user;

--
-- Name: categories; Type: TABLE; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE TABLE public.categories (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    name character varying(100) NOT NULL,
    description text,
    icon_url text,
    base_price numeric(10,2) DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    warranty_options integer[] DEFAULT '{7,15,30,90}'::integer[] NOT NULL
);


ALTER TABLE public.categories OWNER TO homefix_db_wuc1_user;

--
-- Name: cms_announcements; Type: TABLE; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE TABLE public.cms_announcements (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    title character varying(200) NOT NULL,
    body text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    starts_at timestamp with time zone,
    ends_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.cms_announcements OWNER TO homefix_db_wuc1_user;

--
-- Name: cms_banners; Type: TABLE; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE TABLE public.cms_banners (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    title character varying(200),
    image_url text NOT NULL,
    link_url text,
    sort_order integer DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.cms_banners OWNER TO homefix_db_wuc1_user;

--
-- Name: cms_faqs; Type: TABLE; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE TABLE public.cms_faqs (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    question text NOT NULL,
    answer text NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.cms_faqs OWNER TO homefix_db_wuc1_user;

--
-- Name: cms_pages; Type: TABLE; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE TABLE public.cms_pages (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    key character varying(50) NOT NULL,
    title character varying(200) NOT NULL,
    content text NOT NULL,
    updated_by uuid,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.cms_pages OWNER TO homefix_db_wuc1_user;

--
-- Name: consultations; Type: TABLE; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE TABLE public.consultations (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    customer_id uuid NOT NULL,
    technician_id uuid,
    category_id uuid NOT NULL,
    status character varying(20) DEFAULT 'searching'::character varying NOT NULL,
    fee numeric(10,2) DEFAULT 199 NOT NULL,
    duration_seconds integer,
    payment_status character varying(20) DEFAULT 'pending'::character varying NOT NULL,
    escalated_booking_id uuid,
    started_at timestamp with time zone,
    ended_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    reconnect_count integer DEFAULT 0 NOT NULL,
    connection_quality character varying(10),
    rating integer,
    rating_comment text,
    decline_reason text,
    scheduled_at timestamp with time zone,
    recommendation_summary text,
    recommendation_price numeric(10,2),
    recommendation_status character varying(20),
    recommendation_sent_at timestamp without time zone,
    note text,
    area character varying(120),
    ai_diagnosis_session_id uuid,
    CONSTRAINT consultations_rating_check CHECK (((rating IS NULL) OR ((rating >= 1) AND (rating <= 5))))
);


ALTER TABLE public.consultations OWNER TO homefix_db_wuc1_user;

--
-- Name: dispute_evidence; Type: TABLE; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE TABLE public.dispute_evidence (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    dispute_id uuid NOT NULL,
    uploaded_by uuid NOT NULL,
    file_url text NOT NULL,
    note text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.dispute_evidence OWNER TO homefix_db_wuc1_user;

--
-- Name: disputes; Type: TABLE; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE TABLE public.disputes (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    booking_id uuid,
    consultation_id uuid,
    raised_by uuid NOT NULL,
    reason text NOT NULL,
    status character varying(30) DEFAULT 'open'::character varying NOT NULL,
    refund_amount numeric(10,2),
    admin_notes text,
    resolved_by uuid,
    resolved_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT disputes_one_subject_chk CHECK (((((booking_id IS NOT NULL))::integer + ((consultation_id IS NOT NULL))::integer) = 1))
);


ALTER TABLE public.disputes OWNER TO homefix_db_wuc1_user;

--
-- Name: notifications; Type: TABLE; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE TABLE public.notifications (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    user_id uuid NOT NULL,
    title character varying(255) NOT NULL,
    body text NOT NULL,
    data jsonb,
    is_read boolean DEFAULT false NOT NULL,
    sent_via_fcm boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.notifications OWNER TO homefix_db_wuc1_user;

--
-- Name: payments; Type: TABLE; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE TABLE public.payments (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    booking_id uuid NOT NULL,
    user_id uuid NOT NULL,
    amount numeric(10,2) NOT NULL,
    currency character varying(10) DEFAULT 'INR'::character varying NOT NULL,
    method character varying(20),
    status character varying(20) DEFAULT 'created'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    transaction_ref character varying(64),
    upi_txn_id character varying(100),
    invoice_number character varying(50),
    upi_status character varying(20),
    upi_response_code character varying(20),
    upi_approval_ref character varying(100),
    verified boolean DEFAULT false NOT NULL,
    platform_commission numeric(10,2),
    technician_earning numeric(10,2),
    refunded_at timestamp with time zone,
    base_amount numeric(10,2),
    gst_amount numeric(10,2),
    gst_percent numeric(5,2),
    is_repeat_customer boolean DEFAULT false NOT NULL,
    repeat_discount_percent double precision,
    repeat_discount_amount double precision,
    cgst_amount numeric(10,2),
    sgst_amount numeric(10,2),
    razorpay_order_id character varying(64),
    razorpay_payment_id character varying(64),
    razorpay_signature character varying(128),
    platform_fee_amount numeric(10,2),
    visit_charge_amount numeric(10,2)
);


ALTER TABLE public.payments OWNER TO homefix_db_wuc1_user;

--
-- Name: reviews; Type: TABLE; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE TABLE public.reviews (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    booking_id uuid,
    customer_id uuid NOT NULL,
    technician_id uuid NOT NULL,
    rating integer NOT NULL,
    comment text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    consultation_id uuid,
    CONSTRAINT reviews_one_subject_chk CHECK (((((booking_id IS NOT NULL))::integer + ((consultation_id IS NOT NULL))::integer) = 1)),
    CONSTRAINT reviews_rating_check CHECK (((rating >= 1) AND (rating <= 5)))
);


ALTER TABLE public.reviews OWNER TO homefix_db_wuc1_user;

--
-- Name: spare_part_orders; Type: TABLE; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE TABLE public.spare_part_orders (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    spare_part_id uuid NOT NULL,
    supplier_id uuid,
    quantity integer NOT NULL,
    unit_cost numeric(10,2) NOT NULL,
    status character varying(20) DEFAULT 'ordered'::character varying NOT NULL,
    ordered_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    received_at timestamp with time zone
);


ALTER TABLE public.spare_part_orders OWNER TO homefix_db_wuc1_user;

--
-- Name: spare_part_stock_movements; Type: TABLE; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE TABLE public.spare_part_stock_movements (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    spare_part_id uuid NOT NULL,
    change_type character varying(20) NOT NULL,
    quantity_delta integer NOT NULL,
    booking_id uuid,
    note text,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.spare_part_stock_movements OWNER TO homefix_db_wuc1_user;

--
-- Name: spare_parts; Type: TABLE; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE TABLE public.spare_parts (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    category_id uuid,
    supplier_id uuid,
    name character varying(150) NOT NULL,
    sku character varying(60),
    description text,
    unit_price numeric(10,2) DEFAULT 0 NOT NULL,
    stock_quantity integer DEFAULT 0 NOT NULL,
    reorder_level integer DEFAULT 5 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.spare_parts OWNER TO homefix_db_wuc1_user;

--
-- Name: suppliers; Type: TABLE; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE TABLE public.suppliers (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    name character varying(150) NOT NULL,
    contact_person character varying(150),
    phone character varying(20),
    email character varying(150),
    address text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.suppliers OWNER TO homefix_db_wuc1_user;

--
-- Name: technicians; Type: TABLE; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE TABLE public.technicians (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    user_id uuid NOT NULL,
    category_id uuid NOT NULL,
    experience_years integer DEFAULT 0 NOT NULL,
    rating_avg numeric(3,2) DEFAULT 0 NOT NULL,
    rating_count integer DEFAULT 0 NOT NULL,
    is_verified boolean DEFAULT false NOT NULL,
    is_available boolean DEFAULT true NOT NULL,
    current_lat double precision,
    current_lng double precision,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    address text,
    government_id_url text,
    profile_photo_url text,
    approval_status character varying(20) DEFAULT 'pending'::character varying NOT NULL,
    rejection_reason text,
    working_hours jsonb DEFAULT '{"fri": {"open": "09:00", "close": "18:00"}, "mon": {"open": "09:00", "close": "18:00"}, "sat": {"open": "09:00", "close": "18:00"}, "sun": null, "thu": {"open": "09:00", "close": "18:00"}, "tue": {"open": "09:00", "close": "18:00"}, "wed": {"open": "09:00", "close": "18:00"}}'::jsonb NOT NULL,
    CONSTRAINT chk_technicians_approval_status CHECK (((approval_status)::text = ANY ((ARRAY['pending'::character varying, 'approved'::character varying, 'rejected'::character varying])::text[])))
);


ALTER TABLE public.technicians OWNER TO homefix_db_wuc1_user;

--
-- Name: users; Type: TABLE; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE TABLE public.users (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    phone character varying(15),
    name character varying(100),
    email character varying(150),
    password_hash text,
    role character varying(20) DEFAULT 'customer'::character varying NOT NULL,
    otp_code character varying(6),
    otp_expires_at timestamp with time zone,
    phone_verified boolean DEFAULT false NOT NULL,
    fcm_token text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    photo_url text,
    email_verified boolean DEFAULT false NOT NULL,
    email_otp_code character varying(10),
    email_otp_expires_at timestamp with time zone,
    google_id character varying(255)
);


ALTER TABLE public.users OWNER TO homefix_db_wuc1_user;

--
-- Name: wallet_transactions; Type: TABLE; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE TABLE public.wallet_transactions (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    wallet_id uuid NOT NULL,
    type character varying(10) NOT NULL,
    amount numeric(10,2) NOT NULL,
    reason character varying(255),
    reference_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.wallet_transactions OWNER TO homefix_db_wuc1_user;

--
-- Name: wallets; Type: TABLE; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE TABLE public.wallets (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    user_id uuid NOT NULL,
    balance numeric(10,2) DEFAULT 0 NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.wallets OWNER TO homefix_db_wuc1_user;

--
-- Data for Name: addresses; Type: TABLE DATA; Schema: public; Owner: homefix_db_wuc1_user
--

COPY public.addresses (id, user_id, label, line1, line2, city, state, pincode, latitude, longitude, is_default, created_at) FROM stdin;
cf6dcd0c-148b-4463-a20a-dfb2d1818b33	dc3f702c-b385-4c27-9057-0325c0b5013d	Home	Vashi, Navi Mumbai, Maharashtra, 400703, India	room no 519	Navi Mumbai	Maharashtra	400709	19.0841837	73.0154878	t	2026-08-29 06:46:29.979045+00
1dec1ea7-7e4a-4b07-97cd-844c5e86015d	aebfbed2-7205-437b-9045-65d1b0240e6a	Home	Bhandup		mumbai	maharashtra	400008	\N	\N	f	2026-08-29 07:21:39.60909+00
baadacd1-e570-4cb5-9cbf-0b75198d43f2	4f3d12f3-d8a6-4c97-8016-2d44b252426f	Home	Vashi, Navi Mumbai, Maharashtra, 400703, India	3074, 3rd Akshar business park	Navi Mumbai	Maharashtra	400703	19.084199	73.0154883	t	2026-08-29 07:46:33.920485+00
e3bdc6f5-88d2-4174-8f39-f92892457e59	5978c7ed-c201-40f9-ac16-08fcb5d81431	kharghar	navi mumbai		navi mumbai	maharshtra	410210	\N	\N	f	2026-08-29 08:05:31.926686+00
15c8fcef-a955-4e05-8fa4-c15aeee3ff56	ef023969-5324-493a-ad92-0ce013f4a1ca	Home	ddd		gvv	vv	50005	\N	\N	f	2026-08-29 08:48:12.938337+00
ff6bd475-bd7d-4b77-b120-8a9f6d5d479f	3be2026d-ea02-43f3-bc41-e0b3e9bb133c	Home	Vashi, Navi Mumbai, Maharashtra, 400703, India		Navi Mumbai	Maharashtra	400709	19.0841924	73.0155115	t	2026-09-01 06:23:01.555805+00
30dec4a6-9c9f-482f-8e2b-37e6853404dc	aebfbed2-7205-437b-9045-65d1b0240e6a	Home	Vashi, Navi Mumbai, Maharashtra, 400703, India		Navi Mumbai	Maharashtra	400709	19.0842171	73.015489	t	2026-09-01 07:52:51.802997+00
e3c80060-e10b-4942-b45c-b0706277a7bd	064fad8e-000a-4ed1-a447-160afea13815	Home	ghansoli		mumbai	maharashtra	400008	\N	\N	f	2026-09-01 10:59:09.223662+00
80c85490-8d0b-4147-89be-3b734106ae3e	9dd63068-5ba2-487e-ab79-aa0bb4f686f5	Kharghar	navi mumbai		navi mumbai	maharshtra	410210	\N	\N	f	2026-09-04 02:33:23.940447+00
\.


--
-- Data for Name: ai_diagnosis_messages; Type: TABLE DATA; Schema: public; Owner: homefix_db_wuc1_user
--

COPY public.ai_diagnosis_messages (id, session_id, role, content, created_at) FROM stdin;
6dc15dec-8ee7-40b0-b1c8-b55140327417	b0ec1758-b81d-4ef4-ac67-0589606a58ee	user	want Ac service\n\nAc is not working pr\n\n(Customer attached 2 photo(s): http://localhost:8080/uploads/4e67a271-c72b-4a6a-af4f-0433bb498120.jpg, http://localhost:8080/uploads/14cb123d-d4e1-498f-a254-0071c2a0b2c6.jpg)	2026-08-29 08:01:23.491885+00
3da40207-7f24-4ffa-9e04-dbe1955ee8b8	b0ec1758-b81d-4ef4-ac67-0589606a58ee	assistant	{\n  "possible_fault": "Air conditioner not turning on or not cooling",\n  "causes": [\n    "Power supply or breaker tripped",\n    "Thermostat set incorrectly or faulty",\n    "Clogged air filter",\n    "Refrigerant leak",\n    "Compressor or fan motor failure"\n  ],\n  "follow_up_questions": [\n    "Is the AC completely dead (no display or sound) or does it run but not cool?",\n    "Do you see any error codes or flashing lights on the unit?",\n    "When was the last professional service performed?",\n    "Are there any unusual noises, smells, or water leakage?",\n    "What is the model number and age of the AC unit?"\n  ],\n  "confidence_score": 45,\n  "estimated_cost_min": 2500,\n  "estimated_cost_max": 8000,\n  "estimated_time_minutes": 90,\n  "can_solve_remotely": false,\n  "recommendation": "onsite"\n}	2026-08-29 08:01:24.898995+00
874214d3-9b63-414f-a2c4-d9250f8db088	a40903d9-00bd-4ac3-999b-23985a51e914	user	want Ac service\n\nAc is not working pr\n\n(Customer attached 2 photo(s): http://localhost:8080/uploads/2df02710-5c52-4844-9599-c9b518e5b349.jpg, http://localhost:8080/uploads/23656a69-e6fc-4808-9d17-559a93ec45f7.jpg)	2026-08-29 08:30:29.943275+00
77cccb79-5348-4980-93f5-a9a9945ceb21	a40903d9-00bd-4ac3-999b-23985a51e914	assistant	{\n  "possible_fault": "Air conditioner not cooling",\n  "causes": [\n    "Thermostat set to wrong mode or temperature",\n    "Dirty or clogged air filter",\n    "Low refrigerant level or leak",\n    "Compressor or fan motor failure",\n    "Electrical connection or breaker issue"\n  ],\n  "follow_up_questions": [\n    "Is the AC unit turning on at all (display lights or fan running)?",\n    "Do you hear any unusual noises or the compressor trying to start?",\n    "When was the last time the air filter was cleaned or replaced?",\n    "Is the thermostat set to cooling mode with an appropriate temperature?",\n    "Have you noticed any water leakage or strange odors near the unit?"\n  ],\n  "confidence_score": 42,\n  "estimated_cost_min": 2500,\n  "estimated_cost_max": 8000,\n  "estimated_time_minutes": 90,\n  "can_solve_remotely": false,\n  "recommendation": "onsite"\n}	2026-08-29 08:30:31.279339+00
d4f5c32e-88b1-4dfa-8572-d784d9cc44e2	377d5ca4-808d-445c-b90b-26c7f606f836	user	issue\n\nIshu\n\n(Customer attached 1 photo(s): http://localhost:8080/uploads/270487a5-0fd0-4d6f-abd9-93a919a6cfbb.jpg)	2026-08-29 08:31:16.661174+00
5ac4416c-f5f8-4339-92a5-53f8a393ce07	377d5ca4-808d-445c-b90b-26c7f606f836	assistant	{\n  "possible_fault": "Undetermined – insufficient information",\n  "causes": ["Insufficient description of the problem", "Unable to view the photo content"],\n  "follow_up_questions": [\n    "Can you describe the issue you are experiencing (e.g., leaking pipe, faulty switch, appliance not turning on)?",\n    "Which specific appliance, fixture, or area of the house does the problem relate to?",\n    "When did the problem start and does it occur consistently or intermittently?",\n    "Did you notice any unusual sounds, smells, or visual signs (e.g., water stains, sparks, error codes)?"\n  ],\n  "confidence_score": 30,\n  "estimated_cost_min": 500,\n  "estimated_cost_max": 2500,\n  "estimated_time_minutes": 60,\n  "can_solve_remotely": false,\n  "recommendation": "onsite"\n}	2026-08-29 08:31:17.50945+00
ae59bedc-9519-485f-803f-a98b28c450e1	8b4a27a6-12f5-4ec5-933c-ba5b4697058d	user	want\n\nwant\n\n(Customer attached 1 photo(s): http://localhost:8080/uploads/7242daa6-7c47-4d28-b72e-d272a72e0861.jpg)	2026-08-29 08:32:11.736201+00
8d153cb9-27c6-489d-8919-c4052ec07cd3	8b4a27a6-12f5-4ec5-933c-ba5b4697058d	assistant	{\n  "possible_fault": "Unspecified issue",\n  "causes": [],\n  "follow_up_questions": [\n    "Can you describe the problem you are experiencing in detail?",\n    "Which part of your home or which appliance is affected?",\n    "When did the issue first start?",\n    "Are there any unusual sounds, smells, or visual signs?"\n  ],\n  "confidence_score": 30,\n  "estimated_cost_min": 500,\n  "estimated_cost_max": 1500,\n  "estimated_time_minutes": 60,\n  "can_solve_remotely": false,\n  "recommendation": "onsite"\n}	2026-08-29 08:32:13.05207+00
528d9cf0-d0cb-41fc-bf54-0d0c26d04600	debe7f05-1811-42b5-a7c4-074704f61261	user	issue\n\nissue\n\n(Customer attached 1 photo(s): http://localhost:8080/uploads/8ce0ffb6-3005-4960-9213-0d5170152ea2.jpg)	2026-08-29 08:33:05.183177+00
be7918b3-8f8a-4ef8-b3a9-a1677733fb33	debe7f05-1811-42b5-a7c4-074704f61261	assistant	{\n  "possible_fault": "unspecified issue",\n  "causes": ["insufficient information provided", "potential malfunction of an unknown appliance or system"],\n  "follow_up_questions": [\n    "Can you describe the problem you are experiencing (e.g., noise, leak, no power, etc.)?",\n    "Which appliance, fixture, or area of the house is affected?",\n    "When did the issue start and has it gotten worse?",\n    "Did you notice any unusual sounds, smells, or visual signs before the issue occurred?"\n  ],\n  "confidence_score": 20,\n  "estimated_cost_min": 500,\n  "estimated_cost_max": 1500,\n  "estimated_time_minutes": 30,\n  "can_solve_remotely": false,\n  "recommendation": "onsite"\n}	2026-08-29 08:33:06.343464+00
eec18c0f-13b9-45c6-9c0d-e9f22d6cab68	ad8de143-b4e7-4e03-bb86-bdfaac74eda4	user	ac is not working\n\nmy ac is not working\n\n(Customer attached 1 photo(s): http://localhost:8080/uploads/a979fd04-0240-4418-98d8-f23f6463ab03.jpg)	2026-08-29 08:33:59.410692+00
3ed83d8d-63ff-41fc-a1c1-94d01ea26212	ad8de143-b4e7-4e03-bb86-bdfaac74eda4	assistant	{\n  "possible_fault": "Air conditioner not turning on or not cooling",\n  "causes": [\n    "Power supply or circuit breaker tripped",\n    "Thermostat set incorrectly or faulty",\n    "Clogged air filter",\n    "Refrigerant leak or low charge",\n    "Compressor or fan motor failure"\n  ],\n  "follow_up_questions": [\n    "Is the AC unit completely dead (no lights or sound) or does it run but not cool?",\n    "Do you hear any clicking, humming, or other noises when you try to start it?",\n    "Is the thermostat set to COOL mode with a temperature lower than the room temperature?",\n    "When was the last time the AC received professional maintenance?"\n  ],\n  "confidence_score": 35,\n  "estimated_cost_min": 1500,\n  "estimated_cost_max": 8000,\n  "estimated_time_minutes": 90,\n  "can_solve_remotely": false,\n  "recommendation": "onsite"\n}	2026-08-29 08:34:00.788258+00
e12df4d8-1f1c-40f7-89bc-726aacd45eb3	d9d4199b-41cf-4f03-94b0-f6a13979d7a7	user	my ac falls back to room\n\nwosos odo\n Stop over here.\n माझने इसी खराब जाने में ले ठीक को मिलोगी	2026-08-29 08:45:42.152764+00
71a8ac0b-6241-41d6-8ffc-578b1ab32e0c	d9d4199b-41cf-4f03-94b0-f6a13979d7a7	assistant	{\n  "possible_fault": "AC not cooling properly, likely low refrigerant or dirty filter",\n  "causes": [\n    "Low refrigerant level due to leak",\n    "Clogged air filter or evaporator coil",\n    "Faulty thermostat or sensor",\n    "Condenser unit obstructed or dirty"\n  ],\n  "follow_up_questions": [\n    "Is the AC turning on and the fan running normally?",\n    "Do you notice any unusual noises or error codes on the display?",\n    "When did the cooling issue start, and was it sudden or gradual?",\n    "When was the last time the air filter was cleaned or replaced?"\n  ],\n  "confidence_score": 45,\n  "estimated_cost_min": 1500,\n  "estimated_cost_max": 5000,\n  "estimated_time_minutes": 90,\n  "can_solve_remotely": false,\n  "recommendation": "onsite"\n}	2026-08-29 08:45:43.596988+00
93bb58b3-66dc-456d-a2cd-c9703885213a	581026b8-e5c9-463e-85e0-2d4fd12fe426	user	ceiling fan issue\n\njexvjvxei	2026-08-29 10:30:17.239532+00
1a3451dd-b1ee-4157-a84c-4f6b84d4dd63	3416f19a-9cbe-4599-96ec-ecb707ac33c8	assistant	{\n  "possible_fault": "Potential ceiling water damage",\n  "causes": ["roof leak", "plumbing leak"],\n  "follow_up_questions": ["Is there discoloration or stains?", "Any recent roof repairs?", "Is there a drip or moisture?"],\n  "confidence_score": 30,\n  "estimated_cost_min": 1500,\n  "estimated_cost_max": 5000,\n  "estimated_time_minutes": 60,\n  "can_solve_remotely": false,\n  "recommendation": "onsite"\n}	2026-09-01 11:28:12.105569+00
142a17bd-bd91-4b4a-b014-f09666f4009d	3416f19a-9cbe-4599-96ec-ecb707ac33c8	user	hiii	2026-09-01 11:28:23.630944+00
6d50071c-d27e-41a1-80d1-818d9a939f62	581026b8-e5c9-463e-85e0-2d4fd12fe426	assistant	{\n  "possible_fault": "Ceiling fan not operating or intermittent",\n  "causes": [\n    "Loose wiring connection",\n    "Faulty wall switch or pull‑chain switch",\n    "Burnt out motor or faulty capacitor"\n  ],\n  "follow_up_questions": [\n    "Is the fan completely dead, making any noise, or only wobbling/slow?",\n    "Does the fan turn on when you use a different wall switch or control?",\n    "Did the fan work previously and stop suddenly, or has it been problematic for a while?",\n    "Do you hear any humming or buzzing sounds when the fan is switched on?"\n  ],\n  "confidence_score": 35,\n  "estimated_cost_min": 800,\n  "estimated_cost_max": 2500,\n  "estimated_time_minutes": 60,\n  "can_solve_remotely": false,\n  "recommendation": "onsite"\n}	2026-08-29 10:30:18.886529+00
6e2deb52-bab5-42ab-8e94-8b2eb2ae95ef	91f4ca18-f51e-4334-84ae-c7b68e84cd49	user	rhuio\n\ndguio	2026-08-29 10:35:11.235741+00
c29fa215-3797-4703-bdce-1ffd14b8c92c	91f4ca18-f51e-4334-84ae-c7b68e84cd49	assistant	{\n  "possible_fault": "Unclear issue",\n  "causes": [],\n  "follow_up_questions": [\n    "Could you please describe the problem you are experiencing in detail?",\n    "What appliance or area of the home is affected?",\n    "When did the issue first start?",\n    "Are there any visible signs or symptoms (e.g., noise, leak, error code)?"\n  ],\n  "confidence_score": 20,\n  "estimated_cost_min": 500,\n  "estimated_cost_max": 1000,\n  "estimated_time_minutes": 30,\n  "can_solve_remotely": false,\n  "recommendation": "onsite"\n}	2026-08-29 10:35:12.620836+00
c998b90e-3ff4-4543-b291-0c5608b47e5a	b73d460b-e5ae-401f-993b-1cf40f734a7b	user	ac issue\n\nAC not working	2026-08-29 10:35:39.488882+00
3a7eef1e-dc66-49a6-98bb-d8fa1cc40133	b73d460b-e5ae-401f-993b-1cf40f734a7b	assistant	{\n  "possible_fault": "Air conditioner not cooling or not turning on",\n  "causes": [\n    "Dirty or clogged air filter",\n    "Thermostat or remote control settings issue",\n    "Low refrigerant level or leak",\n    "Faulty compressor or fan motor",\n    "Electrical wiring or circuit breaker problem"\n  ],\n  "follow_up_questions": [\n    "Is the AC unit powering on at all, or is it completely dead?",\n    "Is the fan blowing air but not producing cold air?",\n    "Do you hear any unusual noises (clicking, humming, buzzing) when the unit is switched on?",\n    "When was the last time the AC was serviced or the filter cleaned?",\n    "Are the thermostat or remote control displaying the correct temperature setting?"\n  ],\n  "confidence_score": 45,\n  "estimated_cost_min": 2000,\n  "estimated_cost_max": 8000,\n  "estimated_time_minutes": 90,\n  "can_solve_remotely": false,\n  "recommendation": "onsite"\n}	2026-08-29 10:35:40.854475+00
fff5490a-31f7-4dbb-9a07-dd958dfe67a1	60cc5655-5c14-4c64-b593-1d1414177e75	user	dyjk\n\neuo0	2026-08-29 17:41:55.525699+00
05293449-d5e8-4189-8a39-a23681d053cf	60cc5655-5c14-4c64-b593-1d1414177e75	assistant	{\n  "possible_fault": "Insufficient information",\n  "causes": [],\n  "follow_up_questions": [\n    "Can you describe the issue you are experiencing?",\n    "Which appliance or system is affected (plumbing, electrical, AC, etc.)?",\n    "When did the problem start and were there any recent changes?"\n  ],\n  "confidence_score": 20,\n  "estimated_cost_min": 500,\n  "estimated_cost_max": 1500,\n  "estimated_time_minutes": 30,\n  "can_solve_remotely": false,\n  "recommendation": "onsite"\n}	2026-08-29 17:41:57.023162+00
bf30dd22-2336-4141-96fd-8e4c33a6a25c	94a56347-c34d-4d89-88bf-b3e5a560d6ca	user	dyjk\n\neuo0	2026-08-29 17:55:43.371541+00
4836d6f0-dcc0-4048-8faa-fa25d9017f62	94a56347-c34d-4d89-88bf-b3e5a560d6ca	assistant	{\n  "possible_fault": "Insufficient information to determine fault",\n  "causes": [],\n  "follow_up_questions": [\n    "Can you describe the issue you are experiencing in detail?",\n    "Which part of the home (room, appliance, system) is affected?",\n    "When did the problem start and what were the circumstances?"\n  ],\n  "confidence_score": 30,\n  "estimated_cost_min": 500,\n  "estimated_cost_max": 1500,\n  "estimated_time_minutes": 30,\n  "can_solve_remotely": false,\n  "recommendation": "onsite"\n}	2026-08-29 17:55:44.201978+00
eeb5acea-b162-4411-9cfc-fecff80cd61a	97b7cd5d-1ef7-455e-8bec-467ae2934ca5	user	rtuu\n\ndyuoooufd	2026-08-30 01:06:40.728505+00
fdfb2a0a-3623-4829-8884-4a9c6ff9900b	97b7cd5d-1ef7-455e-8bec-467ae2934ca5	assistant	{\n  "possible_fault": "Insufficient information to determine fault",\n  "causes": [],\n  "follow_up_questions": [\n    "Can you describe the problem you are experiencing in detail?",\n    "Which part of the home (e.g., kitchen, bathroom, living room) is affected?",\n    "When did the issue start, and any recent changes or events related to it?"\n  ],\n  "confidence_score": 20,\n  "estimated_cost_min": 500,\n  "estimated_cost_max": 1200,\n  "estimated_time_minutes": 30,\n  "can_solve_remotely": false,\n  "recommendation": "onsite"\n}	2026-08-30 01:06:41.505225+00
cc97e483-9c45-4f23-bafa-c8facbb3eca2	af0eff9d-862c-4eac-a6af-eda2b92710b0	user	rtuu\n\ndyuoooufd	2026-08-30 01:07:03.650388+00
c79f7b21-00df-445b-9527-da181d0a850d	af0eff9d-862c-4eac-a6af-eda2b92710b0	assistant	{\n  "possible_fault": "Insufficient information to determine fault",\n  "causes": [],\n  "follow_up_questions": [\n    "Can you describe the problem you are experiencing in detail?",\n    "Which appliance, fixture, or area of the house is affected?",\n    "When did the issue start, and have there been any recent changes or events?"\n  ],\n  "confidence_score": 20,\n  "estimated_cost_min": 0,\n  "estimated_cost_max": 0,\n  "estimated_time_minutes": 0,\n  "can_solve_remotely": false,\n  "recommendation": "onsite"\n}	2026-08-30 01:07:04.649113+00
58a48a25-e68b-47f9-93e3-acb1e3d0d0ab	4ff951eb-c177-423f-a782-e38cf52c80a3	user	j5j6eke6\n\nymke6kr6rl	2026-08-30 02:46:44.033197+00
ea50a12e-f37c-4cdc-9586-d7804fb2448f	4ff951eb-c177-423f-a782-e38cf52c80a3	assistant	{\n  "possible_fault": "Insufficient information to determine fault",\n  "causes": [],\n  "follow_up_questions": [\n    "Could you describe the problem you are experiencing in detail?",\n    "Which part of the house or which appliance is affected?",\n    "When did the issue start and are there any visible signs (e.g., noises, leaks, error codes)?"\n  ],\n  "confidence_score": 20,\n  "estimated_cost_min": 500,\n  "estimated_cost_max": 1500,\n  "estimated_time_minutes": 30,\n  "can_solve_remotely": false,\n  "recommendation": "onsite"\n}	2026-08-30 02:46:45.418899+00
66cedf44-f12b-4243-bc86-4f967f2de4b6	1a683fec-20f7-4aca-b826-770c28e0cbb5	user	rtuio\n\nduioogf	2026-08-30 03:22:41.682678+00
3d461946-283b-484e-94a3-0193e490d67c	1a683fec-20f7-4aca-b826-770c28e0cbb5	assistant	{\n  "possible_fault": "Insufficient information to determine fault",\n  "causes": [],\n  "follow_up_questions": [\n    "Could you please describe the issue you are experiencing in detail?",\n    "Which part of the home (e.g., kitchen, bathroom, living room) and which appliance or system is involved?",\n    "When did the problem start and does it happen continuously or intermittently?",\n    "Have you noticed any sounds, smells, leaks, or error messages related to the problem?"\n  ],\n  "confidence_score": 30,\n  "estimated_cost_min": 500,\n  "estimated_cost_max": 1500,\n  "estimated_time_minutes": 60,\n  "can_solve_remotely": false,\n  "recommendation": "onsite"\n}	2026-08-30 03:22:42.900968+00
d8b02691-81c1-465e-bae7-42c35f0151b1	574031c4-57a6-4e41-b90c-6dff1c31816d	user	ceiling\n\nyehhd heidjh usidih	2026-08-31 03:10:38.874247+00
41d5b3a9-d9a6-42cd-8d01-eaae38e6a8ed	574031c4-57a6-4e41-b90c-6dff1c31816d	assistant	{\n  "possible_fault": "Potential ceiling issue (e.g., water damage, cracks, paint deterioration)",\n  "causes": ["Water leakage from roof or pipe", "Structural settlement causing cracks", "Aging paint or surface wear"],\n  "follow_up_questions": ["Can you describe the specific problem (e.g., cracks, stains, sagging, peeling paint)?", "When did you first notice the issue?", "Is there any water leak or moisture visible on the ceiling?", "Which room or area of the ceiling is affected?"],\n  "confidence_score": 30,\n  "estimated_cost_min": 500,\n  "estimated_cost_max": 1200,\n  "estimated_time_minutes": 45,\n  "can_solve_remotely": false,\n  "recommendation": "onsite"\n}	2026-08-31 03:10:39.955768+00
16076da6-846f-4705-ac5c-e17e19d0561b	8804a6c2-e525-49c3-b003-812ca03fd2c1	user	ceiling\n\nyehhd heidjh usidih	2026-08-31 03:10:56.303379+00
f07e9b26-254d-49fc-b6cd-7548aca1a56a	8804a6c2-e525-49c3-b003-812ca03fd2c1	assistant	{\n  "possible_fault": "Potential ceiling damage (e.g., water leak, cracks, or paint issues)",\n  "causes": ["Roof leak", "Plumbing pipe leak above ceiling", "Structural movement causing cracks", "Paint deterioration"],\n  "follow_up_questions": [\n    "What specific symptoms are you observing (stains, cracks, sagging, peeling paint, etc.)?",\n    "Where on the ceiling is the issue located (room, wall side, near windows, etc.)?",\n    "Have you noticed any water leakage or dampness in the area above the ceiling?",\n    "When did you first notice the problem and has it worsened over time?",\n    "Is there any recent construction or roof work that was done nearby?"\n  ],\n  "confidence_score": 38,\n  "estimated_cost_min": 1500,\n  "estimated_cost_max": 3500,\n  "estimated_time_minutes": 60,\n  "can_solve_remotely": false,\n  "recommendation": "onsite"\n}	2026-08-31 03:10:57.398237+00
afb792cb-8341-4f3a-94e1-2a56f3d20d9f	8e61fdec-d9af-4dd1-a8a4-796b0df08b61	user	ceiling\n\nyehhd heidjh usidih	2026-08-31 03:11:05.440958+00
9bb8d2d1-a15e-43b4-bacf-4748b130b7aa	8e61fdec-d9af-4dd1-a8a4-796b0df08b61	assistant	{\n  "possible_fault": "Potential ceiling damage (e.g., water leak, crack, or structural issue)",\n  "causes": ["roof leak", "settlement cracks", "humidity condensation", "poor installation"],\n  "follow_up_questions": [\n    "Can you describe the exact symptoms (e.g., water stains, cracks, sagging, discoloration)?",\n    "When did you first notice the problem and has it worsened over time?",\n    "Is there any recent roof work, plumbing leaks, or moisture sources nearby?",\n    "Are the affected areas localized or spread across the ceiling?"\n  ],\n  "confidence_score": 35,\n  "estimated_cost_min": 800,\n  "estimated_cost_max": 3500,\n  "estimated_time_minutes": 90,\n  "can_solve_remotely": false,\n  "recommendation": "onsite"\n}	2026-08-31 03:11:06.422445+00
3938efeb-bdeb-486c-80e1-85c81823c189	2a6323fa-65bf-4df6-83c6-397e58663546	user	ceiling\n\nyehhd heidjh usidih	2026-08-31 03:11:15.899703+00
936812c2-fbe3-495e-9bdf-568e61a8048b	2a6323fa-65bf-4df6-83c6-397e58663546	assistant	{\n  "possible_fault": "Potential ceiling water leak or structural damage",\n  "causes": ["Roof leak", "Burst pipe above ceiling", "Settling cracks", "Moisture intrusion"],\n  "follow_up_questions": [\n    "Is there any visible water staining or discoloration on the ceiling?",\n    "Do you notice any dripping or sound of water when it rains?",\n    "Are there any cracks, sagging, or bulges in the ceiling area?",\n    "When did you first notice the issue?"\n  ],\n  "confidence_score": 35,\n  "estimated_cost_min": 1500,\n  "estimated_cost_max": 5000,\n  "estimated_time_minutes": 60,\n  "can_solve_remotely": false,\n  "recommendation": "onsite"\n}	2026-08-31 03:11:17.087016+00
e7c140d7-2fe9-4dac-b4ce-e5acd35f84af	73681a60-6034-46b8-8dad-e284de4c49aa	user	ceiling\n\nyehhd heidjh usidih	2026-08-31 03:11:43.024459+00
e2569a89-48c8-4323-b37e-57c25faa0182	73681a60-6034-46b8-8dad-e284de4c49aa	assistant	{\n  "possible_fault": "Ceiling issue (possible water leak or structural damage)",\n  "causes": ["Roof leakage", "Plumbing pipe leak above ceiling", "Structural sag or settlement", "Mold growth due to moisture"],\n  "follow_up_questions": [\n    "Can you describe any visible stains, cracks, or discoloration on the ceiling?",\n    "When did you first notice the problem and has it worsened over time?",\n    "Do you notice any water drips, dampness, or a musty odor in the area?",\n    "Is the affected area near a bathroom, kitchen, or roof line?"\n  ],\n  "confidence_score": 38,\n  "estimated_cost_min": 500,\n  "estimated_cost_max": 1500,\n  "estimated_time_minutes": 30,\n  "can_solve_remotely": false,\n  "recommendation": "onsite"\n}	2026-08-31 03:11:44.154668+00
28528b83-d1bd-404d-a4a2-a5f6a486c14b	8ded9c9e-ac5e-4c08-b44e-fd47f3134b63	user	ceiling\n\nyehhd heidjh usidih	2026-08-31 03:11:44.248901+00
a431c29b-8db5-48a2-9699-01be21713f95	8ded9c9e-ac5e-4c08-b44e-fd47f3134b63	assistant	{\n  "possible_fault": "Ceiling damage (potential water leak or structural issue)",\n  "causes": [\n    "Leakage from roof or plumbing above the ceiling",\n    "Structural movement causing cracks or sagging"\n  ],\n  "follow_up_questions": [\n    "Do you see any water stains, discoloration, or dripping on the ceiling?",\n    "Is there a visible crack, sag, or bulge in the ceiling surface?",\n    "When did the problem start and has it worsened over time?",\n    "Is there any recent roofing or plumbing work done in the house?"\n  ],\n  "confidence_score": 30,\n  "estimated_cost_min": 2500,\n  "estimated_cost_max": 8000,\n  "estimated_time_minutes": 60,\n  "can_solve_remotely": false,\n  "recommendation": "onsite"\n}	2026-08-31 03:11:45.506582+00
f2eaa0bf-60a0-4751-8263-5cffcd6a470a	bea1c6a8-7628-46f9-b814-f4be7641d0f6	user	ceiling issue\n\nceiling issue	2026-08-31 03:55:42.450202+00
85682900-ec93-4313-b531-aac536be6a47	bea1c6a8-7628-46f9-b814-f4be7641d0f6	assistant	{\n  "possible_fault": "Potential water damage or structural issue in the ceiling",\n  "causes": [\n    "Roof leak or plumbing pipe leak above the ceiling",\n    "Condensation or humidity causing paint/ceiling board damage",\n    "Structural sagging or poor installation of ceiling material"\n  ],\n  "follow_up_questions": [\n    "Where exactly is the issue located (room, corner, center of ceiling)?",\n    "Do you see any water stains, discoloration, or peeling paint?",\n    "Has the problem worsened after rain or heavy water usage?",\n    "Are there any visible cracks, bulges, or sagging in the ceiling?",\n    "Do you notice any dripping or moisture on the ceiling surface?"\n  ],\n  "confidence_score": 30,\n  "estimated_cost_min": 2000,\n  "estimated_cost_max": 8000,\n  "estimated_time_minutes": 45,\n  "can_solve_remotely": false,\n  "recommendation": "onsite"\n}	2026-08-31 03:55:43.687538+00
7f14437c-c53c-4825-90b9-3b09f5590b63	19304bdb-e8f4-41db-b309-3900f43397df	user	ceiling issue\n\nceiling issue	2026-08-31 03:57:26.206778+00
395a83cd-a75f-428c-8865-c3a4a09bb142	19304bdb-e8f4-41db-b309-3900f43397df	assistant	{\n  "possible_fault": "Ceiling crack or water damage",\n  "causes": [\n    "Water leak from roof or plumbing pipe",\n    "Structural movement or settling causing cracks",\n    "Improper plaster or finishing work"\n  ],\n  "follow_up_questions": [\n    "Can you describe the exact problem (crack, stain, sag, peeling paint, etc.)?",\n    "When did you first notice the issue?",\n    "Is there any water leakage, dampness, or discoloration around the area?",\n    "Is the problem localized to a small spot or spread across a larger area of the ceiling?"\n  ],\n  "confidence_score": 35,\n  "estimated_cost_min": 1500,\n  "estimated_cost_max": 4000,\n  "estimated_time_minutes": 45,\n  "can_solve_remotely": false,\n  "recommendation": "onsite"\n}	2026-08-31 03:57:27.632038+00
f33dc110-d5f8-4e43-8a69-0fd35662661e	5444bbde-45d7-4675-a406-a17a5203e5c7	user	ceiling\n\nAC चालत नाही आही\n\n(Customer attached 1 photo(s): http://localhost:8080/uploads/e9780955-1bee-47e5-a29b-018e7d848716.jpg)	2026-08-31 17:21:01.703961+00
77e748db-1174-4b04-8588-fe12a074450c	5444bbde-45d7-4675-a406-a17a5203e5c7	assistant	{\n  "possible_fault": "Ceiling split AC unit not powering on",\n  "causes": [\n    "Tripped circuit breaker or blown fuse",\n    "Faulty remote control or dead batteries",\n    "Indoor unit power board failure",\n    "Thermostat/temperature sensor issue"\n  ],\n  "follow_up_questions": [\n    "Does the indoor unit display any lights or error codes when you try to turn it on?",\n    "Do you hear a clicking sound from the indoor or outdoor unit?",\n    "Have you checked the circuit breaker or fused switch for this AC circuit?",\n    "Are the remote control batteries fresh and does the remote show a response on the screen?"\n  ],\n  "confidence_score": 55,\n  "estimated_cost_min": 2000,\n  "estimated_cost_max": 8000,\n  "estimated_time_minutes": 80,\n  "can_solve_remotely": false,\n  "recommendation": "onsite"\n}	2026-08-31 17:21:03.278091+00
41ab170b-8212-4423-8bb1-d5cb6f1fe44b	4b904a36-83fe-40cf-a178-b5cea6e895fe	user	ceiling\n\nAC चालत नाही आही\n\n(Customer attached 1 photo(s): http://localhost:8080/uploads/985d3af4-412d-487f-a48c-b82102c70b68.jpg)	2026-08-31 17:21:36.463073+00
7490f0ec-3680-4582-b5a9-d44642d86434	4b904a36-83fe-40cf-a178-b5cea6e895fe	assistant	{\n  "possible_fault": "Ceiling split AC unit not powering on",\n  "causes": [\n    "Tripped circuit breaker or blown fuse",\n    "Faulty remote control or thermostat settings",\n    "Disconnected power cable to indoor unit",\n    "Failed indoor fan motor or capacitor",\n    "Internal protection lock (e.g., overheating) activated"\n  ],\n  "follow_up_questions": [\n    "Is the outdoor unit receiving power (any lights or sounds)?",\n    "Does the remote control display work or change settings?",\n    "Do you hear any clicking or humming noise when you try to turn it on?",\n    "Has the circuit breaker for the AC been checked or reset?",\n    "Is there any unusual smell, water leakage, or visible damage around the unit?"\n  ],\n  "confidence_score": 55,\n  "estimated_cost_min": 1500,\n  "estimated_cost_max": 5000,\n  "estimated_time_minutes": 90,\n  "can_solve_remotely": false,\n  "recommendation": "onsite"\n}	2026-08-31 17:21:38.031334+00
952ca53c-beea-4461-922b-29af45938706	3d4ba274-8519-4e5e-9b03-23c2ea8ee40b	user	ceiling\n\nAC चालत नाही आही\n\n(Customer attached 1 photo(s): http://localhost:8080/uploads/8732578c-858b-4512-9244-f21bec17385b.jpg)	2026-08-31 17:21:47.732033+00
6598a367-d17b-4814-9b45-18c90f21e494	3d4ba274-8519-4e5e-9b03-23c2ea8ee40b	assistant	{\n  "possible_fault": "Ceiling AC unit not powering on",\n  "causes": [\n    "Tripped circuit breaker or blown fuse",\n    "Faulty remote control or thermostat settings",\n    "Loose or damaged power connection to the indoor unit",\n    "Faulty capacitor or motor in the indoor unit",\n    "Refrigerant low or leak (prevents start-up)"\n  ],\n  "follow_up_questions": [\n    "Is the AC's power LED or display lit when you press the remote or wall switch?",\n    "Did you notice any clicking sound or unusual noise before it stopped working?",\n    "Have you checked the main circuit breaker or fuse for the AC circuit?",\n    "Is the air filter clean or has it been clogged with dust?",\n    "Did the AC stop abruptly or was it after a period of normal operation?"\n  ],\n  "confidence_score": 58,\n  "estimated_cost_min": 1500,\n  "estimated_cost_max": 8000,\n  "estimated_time_minutes": 80,\n  "can_solve_remotely": false,\n  "recommendation": "onsite"\n}	2026-08-31 17:21:49.26303+00
0093add4-f6f1-455a-943b-93cf1a292721	3ccdef7a-17ae-43e3-b1a9-c701ad224f55	user	some issues\n\nruy tujjhg	2026-08-31 17:22:39.986486+00
8d8ca303-7004-4288-96c9-15d9dea18ba2	3ccdef7a-17ae-43e3-b1a9-c701ad224f55	assistant	{\n  "possible_fault": "Undetermined",\n  "causes": [],\n  "follow_up_questions": [\n    "Can you describe the specific problem you are experiencing (e.g., leak, noise, no power, etc.)?",\n    "Which part of the home is affected (kitchen, bathroom, living room, etc.) and what appliance or fixture is involved?",\n    "When did the issue start and has anything changed recently (new appliance, recent work, weather conditions)?"\n  ],\n  "confidence_score": 20,\n  "estimated_cost_min": 500,\n  "estimated_cost_max": 2000,\n  "estimated_time_minutes": 30,\n  "can_solve_remotely": false,\n  "recommendation": "onsite"\n}	2026-08-31 17:22:42.613716+00
27ef0947-c353-40dc-bd2f-b23125ce2873	af377b20-d4b7-449a-9f04-d40ac6574753	user	some issues\n\nruy tujjhg	2026-08-31 17:23:42.606866+00
f460f542-b4aa-40cb-b41a-530dc8ca5bf9	af377b20-d4b7-449a-9f04-d40ac6574753	assistant	{\n  "possible_fault": "Unspecified issue",\n  "causes": [],\n  "follow_up_questions": [\n    "Can you describe the problem you are experiencing in detail?",\n    "Which part of the home (kitchen, bathroom, living area, etc.) is affected?",\n    "Is the issue related to plumbing, electrical, HVAC, appliances, or something else?",\n    "When did the problem start, and does it happen intermittently or continuously?"\n  ],\n  "confidence_score": 30,\n  "estimated_cost_min": 500,\n  "estimated_cost_max": 1500,\n  "estimated_time_minutes": 30,\n  "can_solve_remotely": false,\n  "recommendation": "onsite"\n}	2026-08-31 17:23:43.68098+00
5c5252ba-9f18-487f-834c-8bbddfa31838	ac3b252f-b81b-470b-b4f6-dba77e5bde0e	user	ceiling issue\n\nceiling issue	2026-09-01 07:00:29.372275+00
44685f92-9fa2-4f2d-97db-b4087d3e07ee	ac3b252f-b81b-470b-b4f6-dba77e5bde0e	assistant	{\n  "possible_fault": "Potential structural or moisture-related ceiling damage",\n  "causes": [\n    "Water leak from roof or plumbing",\n    "Structural cracks due to settlement or load",\n    "Paint, plaster, or ceiling tile deterioration"\n  ],\n  "follow_up_questions": [\n    "Is there any visible water staining, discoloration, or dripping on the ceiling?",\n    "Are there cracks, sagging, or bulging areas on the ceiling surface?",\n    "What type of ceiling finish does your home have (paint, plaster, tiles, etc.)?",\n    "When did you first notice the issue and has it worsened over time?",\n    "Have there been any recent roof repairs, plumbing work, or heavy vibrations nearby?"\n  ],\n  "confidence_score": 30,\n  "estimated_cost_min": 500,\n  "estimated_cost_max": 1500,\n  "estimated_time_minutes": 30,\n  "can_solve_remotely": false,\n  "recommendation": "onsite"\n}	2026-09-01 07:00:31.082171+00
78023ba4-94f7-4dd2-aecc-1ba146a93d42	bb3ed09e-8895-4003-9f7f-49ed4aa7a953	user	ceiling issue\n\nceiling issue	2026-09-01 07:00:40.713025+00
afc7d41a-70a0-40b8-af46-d884100f2f2f	bb3ed09e-8895-4003-9f7f-49ed4aa7a953	assistant	{\n  "possible_fault": "Ceiling crack or water stain",\n  "causes": ["Water leakage from roof or plumbing", "Structural movement or settlement causing cracks"],\n  "follow_up_questions": [\n    "Where on the ceiling is the problem (center, corner, near a wall)?",\n    "Is there any discoloration, staining, or mold growth?",\n    "Did you notice any recent roof leaks or pipe bursts?",\n    "Is the ceiling sagging, bulging, or just showing cracks?",\n    "When did you first notice the issue?"\n  ],\n  "confidence_score": 30,\n  "estimated_cost_min": 2000,\n  "estimated_cost_max": 8000,\n  "estimated_time_minutes": 60,\n  "can_solve_remotely": false,\n  "recommendation": "onsite"\n}	2026-09-01 07:00:42.011661+00
771888b9-1c0f-4a41-b29b-b5234744acbe	481adcc0-da9e-4565-ad37-d2e9af3aae19	user	ceiling issue\n\nceiling issue	2026-09-01 07:00:50.974066+00
87df1d2c-e221-4168-960b-928824597bb2	481adcc0-da9e-4565-ad37-d2e9af3aae19	assistant	{\n  "possible_fault": "Potential ceiling damage (e.g., water leak, cracking, sagging)",\n  "causes": [\n    "Water leakage from roof or plumbing",\n    "Structural settlement or framing issues",\n    "Improper plastering or finishing"\n  ],\n  "follow_up_questions": [\n    "Are there visible cracks, stains, or sagging in the ceiling?",\n    "Did the problem start after any recent water usage, roof work, or rain?",\n    "Is there a ceiling fan or light fixture attached to the affected area?",\n    "How long has the issue been present and is it getting worse?"\n  ],\n  "confidence_score": 30,\n  "estimated_cost_min": 1500,\n  "estimated_cost_max": 5000,\n  "estimated_time_minutes": 30,\n  "can_solve_remotely": false,\n  "recommendation": "onsite"\n}	2026-09-01 07:00:52.264978+00
041d3d6c-74de-4979-9894-9cc27c90ffae	a71e4fa1-ec6d-4564-beb2-262f490cbcca	user	fhjj\n\nhkrrsdc	2026-09-01 07:14:15.147526+00
c513edd6-059d-4dd8-b5c1-9a69ebecf6b9	a71e4fa1-ec6d-4564-beb2-262f490cbcca	assistant	{\n  "possible_fault": "Unclear issue",\n  "causes": [],\n  "follow_up_questions": [\n    "Could you please describe the problem you are facing in detail?",\n    "Which part of the house or which appliance is affected?",\n    "When did the issue start, and are there any noticeable symptoms (noise, leak, error codes, etc.)?"\n  ],\n  "confidence_score": 30,\n  "estimated_cost_min": 500,\n  "estimated_cost_max": 1000,\n  "estimated_time_minutes": 30,\n  "can_solve_remotely": false,\n  "recommendation": "onsite"\n}	2026-09-01 07:14:16.012595+00
d304f8a7-809d-4738-b1d2-3bb33f4455fd	d1e2d245-f137-4fb7-9202-95ffa48eff68	user	fhjj\n\nhkrrsdc	2026-09-01 07:14:26.35376+00
3aa8d2e1-cb04-4bc5-ba67-a92c9aa226c4	d1e2d245-f137-4fb7-9202-95ffa48eff68	assistant	{\n  "possible_fault": "Insufficient information to determine fault",\n  "causes": [],\n  "follow_up_questions": [\n    "Can you describe the problem you are experiencing in detail?",\n    "Which part of the house or which appliance is affected?",\n    "When did the issue start and what symptoms are you noticing?"\n  ],\n  "confidence_score": 20,\n  "estimated_cost_min": 500,\n  "estimated_cost_max": 1500,\n  "estimated_time_minutes": 30,\n  "can_solve_remotely": false,\n  "recommendation": "onsite"\n}	2026-09-01 07:14:26.990698+00
2034358b-fdce-4fce-9989-74c8ecea46ae	347a31ea-63f5-4f4c-87a9-ada72fafd6ea	user	fhjj\n\nhkrrsdc	2026-09-01 07:14:31.817654+00
6f265e2d-b5b1-4519-9d50-59c9cbb47f11	347a31ea-63f5-4f4c-87a9-ada72fafd6ea	assistant	{\n  "possible_fault": "Unclear issue due to insufficient description",\n  "causes": [],\n  "follow_up_questions": [\n    "Can you please describe the problem you are experiencing in detail?",\n    "Which part of your home (e.g., kitchen, bathroom, living room) is affected?",\n    "When did the issue start, and does it happen continuously or intermittently?"\n  ],\n  "confidence_score": 20,\n  "estimated_cost_min": 500,\n  "estimated_cost_max": 1500,\n  "estimated_time_minutes": 30,\n  "can_solve_remotely": false,\n  "recommendation": "onsite"\n}	2026-09-01 07:14:32.653967+00
9565c54f-7742-4e5e-bca9-23d409ad3dab	76defd3e-4854-4370-a018-d78704c00fa1	user	ceiling\n\ntheheh ryejjs\n\n(Customer attached 1 photo(s): http://localhost:8080/uploads/366fbd71-84e7-4880-b48d-04c3369eb722.jpg)\n\n(Customer attached 1 video(s): http://localhost:8080/uploads/cfb1a6a3-f092-4e8c-b39e-2e01d2f3df29.mp4)	2026-09-01 08:56:01.507454+00
1ab5eb03-6114-4c7a-9d8d-b3104ed26fcc	76defd3e-4854-4370-a018-d78704c00fa1	assistant	{\n  "possible_fault": "Potential ceiling water damage or structural issue",\n  "causes": [\n    "Roof leak",\n    "Plumbing pipe leak above the ceiling",\n    "Condensation or humidity leading to mold",\n    "Structural crack due to settlement"\n  ],\n  "follow_up_questions": [\n    "When did you first notice the problem and what changes have you observed (stains, sagging, cracks, odor)?",\n    "Is there any visible water leakage or dampness on the floor below?",\n    "Do you notice any recent roof repairs or heavy rainfall that could be related?",\n    "Is there a distinct musty or moldy smell in the area?"\n  ],\n  "confidence_score": 38,\n  "estimated_cost_min": 1500,\n  "estimated_cost_max": 5000,\n  "estimated_time_minutes": 90,\n  "can_solve_remotely": false,\n  "recommendation": "onsite"\n}	2026-09-01 08:56:02.743143+00
9bc4a51f-537f-4799-b357-be4a3521a462	a2f95469-c2f2-4e81-8c5d-415dbfd8ee42	user	ceiling\n\ntheheh ryejjs\n\n(Customer attached 1 photo(s): http://localhost:8080/uploads/29d01d51-4dc8-425c-9083-b9b88f7bc594.jpg)\n\n(Customer attached 1 video(s): http://localhost:8080/uploads/76eed1b1-a606-411a-8d81-ad4f2373dd83.mp4)	2026-09-01 08:57:28.737985+00
e128771f-02ed-443a-af4f-18a1b6466774	a2f95469-c2f2-4e81-8c5d-415dbfd8ee42	assistant	{\n  "possible_fault": "Ceiling damage (possible water leak or structural crack)",\n  "causes": [\n    "Roof leak",\n    "Plumbing pipe leak above the ceiling",\n    "Structural settlement or impact damage"\n  ],\n  "follow_up_questions": [\n    "Can you describe what you see on the ceiling (e.g., water stain, crack, sagging, discoloration)?",\n    "When did you first notice the issue?",\n    "Have you had any recent roof repairs or water leaks from upstairs plumbing?",\n    "Is the problem limited to one spot or spread across a larger area?",\n    "Do you hear any dripping sounds or notice any moisture on the ceiling surface?"\n  ],\n  "confidence_score": 35,\n  "estimated_cost_min": 500,\n  "estimated_cost_max": 2500,\n  "estimated_time_minutes": 60,\n  "can_solve_remotely": false,\n  "recommendation": "onsite"\n}	2026-09-01 08:57:30.239164+00
9bc586cf-6860-4d11-a1f3-4a6e4803754d	807a509f-ee66-48bc-8208-7308480eadac	user	ac cooling issue\n\ncooling issue	2026-09-01 09:50:56.689763+00
f1b7aeda-3045-4ddc-95f5-0a309c7d813e	807a509f-ee66-48bc-8208-7308480eadac	assistant	{\n  "possible_fault": "Insufficient cooling",\n  "causes": ["Low refrigerant", "Dirty filter"],\n  "follow_up_questions": ["Is the AC blowing warm air?", "When did the issue start?", "Any unusual noises?"],\n  "confidence_score": 40,\n  "estimated_cost_min": 2000,\n  "estimated_cost_max": 5000,\n  "estimated_time_minutes": 60,\n  "can_solve_remotely": false,\n  "recommendation": "onsite"\n}	2026-09-01 09:50:57.962842+00
797307fd-a027-4476-9da6-9e15d2b8b076	303d9113-dc3a-4b75-807d-45a61ef8636e	user	ac cooling issue\n\ncooling issue	2026-09-01 09:51:17.898855+00
515d2caf-f589-4bf6-a8de-3aa81bfbfeb0	9d6a6046-d6cf-4b6a-b06e-7dd32ba392d1	user	ac cooling issue\n\ncooling issue	2026-09-01 09:51:18.520992+00
4e81bd85-5bd7-4cac-9e2c-c45e56ed40b7	303d9113-dc3a-4b75-807d-45a61ef8636e	assistant	{\n  "possible_fault": "Insufficient AC cooling",\n  "causes": ["Low refrigerant", "Clogged air filter"],\n  "follow_up_questions": ["Is the air coming out warm or cool?", "Is the fan running continuously?", "When did the problem start?"],\n  "confidence_score": 40,\n  "estimated_cost_min": 2000,\n  "estimated_cost_max": 5000,\n  "estimated_time_minutes": 60,\n  "can_solve_remotely": false,\n  "recommendation": "onsite"\n}	2026-09-01 09:51:19.208296+00
e7549e2f-21fb-422e-b33c-ec9868c39e31	9d6a6046-d6cf-4b6a-b06e-7dd32ba392d1	assistant	{\n  "possible_fault": "Insufficient AC cooling",\n  "causes": ["Low refrigerant", "Clogged filter"],\n  "follow_up_questions": ["Is cold air blowing from vents?", "Is the filter dirty?", "Any ice on the coils?"],\n  "confidence_score": 30,\n  "estimated_cost_min": 2000,\n  "estimated_cost_max": 8000,\n  "estimated_time_minutes": 60,\n  "can_solve_remotely": false,\n  "recommendation": "onsite"\n}	2026-09-01 09:51:19.334494+00
3061ca72-1822-43f2-ba92-ced4068085da	379303b8-ab89-4dff-b354-67c7b97cb6c8	user	ceiling fan\n\nceiling fan issue	2026-09-01 09:58:34.871745+00
ae4e5a2c-7df0-417a-9a83-3e26c4e4a183	379303b8-ab89-4dff-b354-67c7b97cb6c8	assistant	{\n  "possible_fault": "Ceiling fan not operating",\n  "causes": ["Power supply issue", "Faulty fan motor"],\n  "follow_up_questions": ["Is the fan receiving power?", "Does it make any noise when switched on?", "Is the fan blade movement stuck?"],\n  "confidence_score": 35,\n  "estimated_cost_min": 800,\n  "estimated_cost_max": 1500,\n  "estimated_time_minutes": 45,\n  "can_solve_remotely": false,\n  "recommendation": "onsite"\n}	2026-09-01 09:58:36.109459+00
480be587-fc90-40a0-be25-cc2442df85f7	edfa85b7-0b22-42e3-9c09-0f2e4a667c5b	user	cooling issue\n\ncooling system issue	2026-09-01 10:32:16.134223+00
34e99ca4-fa7f-4c3f-8832-6c988133c4c9	edfa85b7-0b22-42e3-9c09-0f2e4a667c5b	assistant	{\n  "possible_fault": "Insufficient cooling",\n  "causes": ["Low refrigerant", "Dirty filters"],\n  "follow_up_questions": ["Is it an air conditioner?", "Does the unit power on?", "Any unusual noise or water leak?"],\n  "confidence_score": 30,\n  "estimated_cost_min": 2000,\n  "estimated_cost_max": 5000,\n  "estimated_time_minutes": 60,\n  "can_solve_remotely": false,\n  "recommendation": "onsite"\n}	2026-09-01 10:32:17.128714+00
8371f029-9693-49d8-ad25-70e5be762049	bf503c8a-6e4b-4192-9723-b3799fbdc014	user	cooling issue\n\nac cooling issue	2026-09-01 10:42:40.516588+00
dfaf5ff6-edef-4cd4-aa8f-c4ce873a6832	bf503c8a-6e4b-4192-9723-b3799fbdc014	assistant	{\n  "possible_fault": "AC not cooling",\n  "causes": ["low refrigerant", "clogged filter"],\n  "follow_up_questions": [\n    "Is the thermostat set to cooling?",\n    "Do you hear the compressor running?",\n    "When was the last filter change?"\n  ],\n  "confidence_score": 35,\n  "estimated_cost_min": 2000,\n  "estimated_cost_max": 8000,\n  "estimated_time_minutes": 60,\n  "can_solve_remotely": false,\n  "recommendation": "onsite"\n}	2026-09-01 10:42:41.564055+00
16e37bd5-8055-4475-a4b1-3575568c0f6d	a31d97c1-5ba2-421a-813b-08d9002893a0	user	cooling issue\n\nac cooling issue	2026-09-01 10:43:25.028327+00
85b00b09-c009-4ffb-9423-24a479e96157	a31d97c1-5ba2-421a-813b-08d9002893a0	assistant	{\n  "possible_fault": "AC not cooling properly",\n  "causes": ["low refrigerant", "clogged air filter"],\n  "follow_up_questions": ["Is the AC blowing warm air?", "Any unusual noises from the unit?", "When did the issue start?"],\n  "confidence_score": 30,\n  "estimated_cost_min": 2500,\n  "estimated_cost_max": 5500,\n  "estimated_time_minutes": 45,\n  "can_solve_remotely": false,\n  "recommendation": "onsite"\n}	2026-09-01 10:43:25.995433+00
2ca84f52-3238-4324-86d3-978b0b44088d	7f8b2418-6749-4a29-8459-13fbb520e2af	user	ac issue\n\nbdhdjjdkd	2026-09-01 10:49:36.907282+00
43331ee8-b377-4dbd-8e37-539674c3c958	7f8b2418-6749-4a29-8459-13fbb520e2af	assistant	{\n  "possible_fault": "Air conditioner not cooling",\n  "causes": ["Insufficient refrigerant", "Clogged filter"],\n  "follow_up_questions": ["Is the unit turning on?", "Is airflow weak?", "Any unusual noises?"],\n  "confidence_score": 42,\n  "estimated_cost_min": 1500,\n  "estimated_cost_max": 3000,\n  "estimated_time_minutes": 30,\n  "can_solve_remotely": false,\n  "recommendation": "onsite"\n}	2026-09-01 10:49:37.925866+00
b56e9765-a6f7-404c-bddc-b97bd11f0bda	3416f19a-9cbe-4599-96ec-ecb707ac33c8	user	ceiling issue\n\ngsuushdudhdh	2026-09-01 11:28:11.117624+00
07cf63d8-374d-4040-8d20-d5d88cc0288c	3416f19a-9cbe-4599-96ec-ecb707ac33c8	assistant	{\n  "possible_fault": "Unclear issue",\n  "causes": [],\n  "follow_up_questions": ["Can you describe the problem?", "Which area of the house is affected?", "When did it start?"],\n  "confidence_score": 20,\n  "estimated_cost_min": 500,\n  "estimated_cost_max": 1000,\n  "estimated_time_minutes": 30,\n  "can_solve_remotely": false,\n  "recommendation": "onsite"\n}	2026-09-01 11:28:24.64413+00
e44f7dd0-e901-4a18-a9a1-268e15e8f0e3	d03952b8-5327-4b27-889e-a9714fbb9bf8	user	cctv issue\n\nfyffygygugu	2026-09-07 06:42:12.195531+00
c600edc3-73e3-40b9-9813-cb6a653cac71	d03952b8-5327-4b27-889e-a9714fbb9bf8	assistant	{\n  "possible_fault": "CCTV not displaying video",\n  "causes": ["Power supply issue", "Network connectivity problem"],\n  "follow_up_questions": ["Are the camera LEDs lit?", "Is the DVR powering on?", "Any error messages on the monitor?"],\n  "confidence_score": 30,\n  "estimated_cost_min": 1500,\n  "estimated_cost_max": 3000,\n  "estimated_time_minutes": 60,\n  "can_solve_remotely": false,\n  "recommendation": "onsite"\n}	2026-09-07 06:42:13.38637+00
\.


--
-- Data for Name: ai_diagnosis_sessions; Type: TABLE DATA; Schema: public; Owner: homefix_db_wuc1_user
--

COPY public.ai_diagnosis_sessions (id, user_id, booking_id, category_id, status, created_at) FROM stdin;
b0ec1758-b81d-4ef4-ac67-0589606a58ee	4f3d12f3-d8a6-4c97-8016-2d44b252426f	\N	67870415-027c-4371-814b-3d80c0f67b7f	active	2026-08-29 08:01:23.381346+00
a40903d9-00bd-4ac3-999b-23985a51e914	4f3d12f3-d8a6-4c97-8016-2d44b252426f	\N	67870415-027c-4371-814b-3d80c0f67b7f	active	2026-08-29 08:30:29.828067+00
377d5ca4-808d-445c-b90b-26c7f606f836	4f3d12f3-d8a6-4c97-8016-2d44b252426f	\N	9d94bcc9-42f8-480c-9dc7-ad5f59bad17b	active	2026-08-29 08:31:16.544157+00
8b4a27a6-12f5-4ec5-933c-ba5b4697058d	4f3d12f3-d8a6-4c97-8016-2d44b252426f	\N	763c06cc-2221-40d6-93db-9557a7c47aec	active	2026-08-29 08:32:11.637572+00
debe7f05-1811-42b5-a7c4-074704f61261	4f3d12f3-d8a6-4c97-8016-2d44b252426f	\N	763c06cc-2221-40d6-93db-9557a7c47aec	active	2026-08-29 08:33:04.978466+00
ad8de143-b4e7-4e03-bb86-bdfaac74eda4	5978c7ed-c201-40f9-ac16-08fcb5d81431	\N	67870415-027c-4371-814b-3d80c0f67b7f	active	2026-08-29 08:33:59.26097+00
d9d4199b-41cf-4f03-94b0-f6a13979d7a7	ef023969-5324-493a-ad92-0ce013f4a1ca	\N	67870415-027c-4371-814b-3d80c0f67b7f	active	2026-08-29 08:45:42.04022+00
581026b8-e5c9-463e-85e0-2d4fd12fe426	aebfbed2-7205-437b-9045-65d1b0240e6a	\N	67870415-027c-4371-814b-3d80c0f67b7f	active	2026-08-29 10:30:17.113079+00
91f4ca18-f51e-4334-84ae-c7b68e84cd49	aebfbed2-7205-437b-9045-65d1b0240e6a	\N	67870415-027c-4371-814b-3d80c0f67b7f	active	2026-08-29 10:35:11.098246+00
b73d460b-e5ae-401f-993b-1cf40f734a7b	aebfbed2-7205-437b-9045-65d1b0240e6a	\N	67870415-027c-4371-814b-3d80c0f67b7f	active	2026-08-29 10:35:39.355568+00
60cc5655-5c14-4c64-b593-1d1414177e75	aebfbed2-7205-437b-9045-65d1b0240e6a	\N	67870415-027c-4371-814b-3d80c0f67b7f	active	2026-08-29 17:41:55.061452+00
94a56347-c34d-4d89-88bf-b3e5a560d6ca	aebfbed2-7205-437b-9045-65d1b0240e6a	\N	67870415-027c-4371-814b-3d80c0f67b7f	active	2026-08-29 17:55:43.112652+00
97b7cd5d-1ef7-455e-8bec-467ae2934ca5	aebfbed2-7205-437b-9045-65d1b0240e6a	\N	997a9d99-74e1-4910-a81a-86e85994026c	active	2026-08-30 01:06:40.546302+00
af0eff9d-862c-4eac-a6af-eda2b92710b0	aebfbed2-7205-437b-9045-65d1b0240e6a	\N	997a9d99-74e1-4910-a81a-86e85994026c	active	2026-08-30 01:07:03.497181+00
4ff951eb-c177-423f-a782-e38cf52c80a3	aebfbed2-7205-437b-9045-65d1b0240e6a	\N	67870415-027c-4371-814b-3d80c0f67b7f	active	2026-08-30 02:46:43.898449+00
1a683fec-20f7-4aca-b826-770c28e0cbb5	aebfbed2-7205-437b-9045-65d1b0240e6a	\N	763c06cc-2221-40d6-93db-9557a7c47aec	active	2026-08-30 03:22:41.540715+00
574031c4-57a6-4e41-b90c-6dff1c31816d	aebfbed2-7205-437b-9045-65d1b0240e6a	\N	67870415-027c-4371-814b-3d80c0f67b7f	active	2026-08-31 03:10:38.751497+00
8804a6c2-e525-49c3-b003-812ca03fd2c1	aebfbed2-7205-437b-9045-65d1b0240e6a	\N	67870415-027c-4371-814b-3d80c0f67b7f	active	2026-08-31 03:10:56.192798+00
8e61fdec-d9af-4dd1-a8a4-796b0df08b61	aebfbed2-7205-437b-9045-65d1b0240e6a	\N	67870415-027c-4371-814b-3d80c0f67b7f	active	2026-08-31 03:11:05.254014+00
2a6323fa-65bf-4df6-83c6-397e58663546	aebfbed2-7205-437b-9045-65d1b0240e6a	\N	67870415-027c-4371-814b-3d80c0f67b7f	active	2026-08-31 03:11:15.704089+00
73681a60-6034-46b8-8dad-e284de4c49aa	aebfbed2-7205-437b-9045-65d1b0240e6a	\N	67870415-027c-4371-814b-3d80c0f67b7f	active	2026-08-31 03:11:42.901604+00
8ded9c9e-ac5e-4c08-b44e-fd47f3134b63	aebfbed2-7205-437b-9045-65d1b0240e6a	\N	67870415-027c-4371-814b-3d80c0f67b7f	active	2026-08-31 03:11:44.124964+00
bea1c6a8-7628-46f9-b814-f4be7641d0f6	aebfbed2-7205-437b-9045-65d1b0240e6a	\N	67870415-027c-4371-814b-3d80c0f67b7f	active	2026-08-31 03:55:42.340495+00
19304bdb-e8f4-41db-b309-3900f43397df	aebfbed2-7205-437b-9045-65d1b0240e6a	\N	67870415-027c-4371-814b-3d80c0f67b7f	active	2026-08-31 03:57:26.019627+00
5444bbde-45d7-4675-a406-a17a5203e5c7	aebfbed2-7205-437b-9045-65d1b0240e6a	\N	67870415-027c-4371-814b-3d80c0f67b7f	active	2026-08-31 17:21:01.56712+00
4b904a36-83fe-40cf-a178-b5cea6e895fe	aebfbed2-7205-437b-9045-65d1b0240e6a	\N	67870415-027c-4371-814b-3d80c0f67b7f	active	2026-08-31 17:21:36.358628+00
3d4ba274-8519-4e5e-9b03-23c2ea8ee40b	aebfbed2-7205-437b-9045-65d1b0240e6a	\N	67870415-027c-4371-814b-3d80c0f67b7f	active	2026-08-31 17:21:47.650777+00
3ccdef7a-17ae-43e3-b1a9-c701ad224f55	aebfbed2-7205-437b-9045-65d1b0240e6a	\N	297f8069-7bb8-4948-a50b-51cd88ba2998	active	2026-08-31 17:22:39.858198+00
af377b20-d4b7-449a-9f04-d40ac6574753	aebfbed2-7205-437b-9045-65d1b0240e6a	\N	297f8069-7bb8-4948-a50b-51cd88ba2998	active	2026-08-31 17:23:42.244166+00
ac3b252f-b81b-470b-b4f6-dba77e5bde0e	aebfbed2-7205-437b-9045-65d1b0240e6a	\N	67870415-027c-4371-814b-3d80c0f67b7f	active	2026-09-01 07:00:29.194169+00
bb3ed09e-8895-4003-9f7f-49ed4aa7a953	aebfbed2-7205-437b-9045-65d1b0240e6a	\N	67870415-027c-4371-814b-3d80c0f67b7f	active	2026-09-01 07:00:40.491728+00
481adcc0-da9e-4565-ad37-d2e9af3aae19	aebfbed2-7205-437b-9045-65d1b0240e6a	\N	67870415-027c-4371-814b-3d80c0f67b7f	active	2026-09-01 07:00:50.762514+00
a71e4fa1-ec6d-4564-beb2-262f490cbcca	aebfbed2-7205-437b-9045-65d1b0240e6a	\N	67870415-027c-4371-814b-3d80c0f67b7f	active	2026-09-01 07:14:14.917534+00
d1e2d245-f137-4fb7-9202-95ffa48eff68	aebfbed2-7205-437b-9045-65d1b0240e6a	\N	67870415-027c-4371-814b-3d80c0f67b7f	active	2026-09-01 07:14:26.255621+00
347a31ea-63f5-4f4c-87a9-ada72fafd6ea	aebfbed2-7205-437b-9045-65d1b0240e6a	\N	67870415-027c-4371-814b-3d80c0f67b7f	active	2026-09-01 07:14:31.708516+00
76defd3e-4854-4370-a018-d78704c00fa1	aebfbed2-7205-437b-9045-65d1b0240e6a	\N	67870415-027c-4371-814b-3d80c0f67b7f	active	2026-09-01 08:56:01.405134+00
a2f95469-c2f2-4e81-8c5d-415dbfd8ee42	aebfbed2-7205-437b-9045-65d1b0240e6a	\N	67870415-027c-4371-814b-3d80c0f67b7f	active	2026-09-01 08:57:28.644708+00
807a509f-ee66-48bc-8208-7308480eadac	aebfbed2-7205-437b-9045-65d1b0240e6a	\N	67870415-027c-4371-814b-3d80c0f67b7f	active	2026-09-01 09:50:56.546486+00
303d9113-dc3a-4b75-807d-45a61ef8636e	aebfbed2-7205-437b-9045-65d1b0240e6a	\N	67870415-027c-4371-814b-3d80c0f67b7f	active	2026-09-01 09:51:17.669379+00
9d6a6046-d6cf-4b6a-b06e-7dd32ba392d1	aebfbed2-7205-437b-9045-65d1b0240e6a	\N	67870415-027c-4371-814b-3d80c0f67b7f	active	2026-09-01 09:51:18.430663+00
379303b8-ab89-4dff-b354-67c7b97cb6c8	aebfbed2-7205-437b-9045-65d1b0240e6a	\N	67870415-027c-4371-814b-3d80c0f67b7f	active	2026-09-01 09:58:34.73693+00
edfa85b7-0b22-42e3-9c09-0f2e4a667c5b	aebfbed2-7205-437b-9045-65d1b0240e6a	\N	67870415-027c-4371-814b-3d80c0f67b7f	active	2026-09-01 10:32:16.033046+00
bf503c8a-6e4b-4192-9723-b3799fbdc014	aebfbed2-7205-437b-9045-65d1b0240e6a	\N	67870415-027c-4371-814b-3d80c0f67b7f	active	2026-09-01 10:42:40.419354+00
a31d97c1-5ba2-421a-813b-08d9002893a0	aebfbed2-7205-437b-9045-65d1b0240e6a	\N	67870415-027c-4371-814b-3d80c0f67b7f	active	2026-09-01 10:43:24.919251+00
7f8b2418-6749-4a29-8459-13fbb520e2af	aebfbed2-7205-437b-9045-65d1b0240e6a	\N	67870415-027c-4371-814b-3d80c0f67b7f	active	2026-09-01 10:49:36.804754+00
3416f19a-9cbe-4599-96ec-ecb707ac33c8	064fad8e-000a-4ed1-a447-160afea13815	\N	67870415-027c-4371-814b-3d80c0f67b7f	active	2026-09-01 11:28:10.983615+00
d03952b8-5327-4b27-889e-a9714fbb9bf8	aebfbed2-7205-437b-9045-65d1b0240e6a	\N	fe0b80e7-c29f-42fc-aa6b-f21062f7baba	active	2026-09-07 06:42:12.043315+00
\.


--
-- Data for Name: audit_logs; Type: TABLE DATA; Schema: public; Owner: homefix_db_wuc1_user
--

COPY public.audit_logs (id, admin_user_id, action, entity_type, entity_id, details, ip_address, created_at) FROM stdin;
7399fcef-287e-4e4e-849c-37ff8ee0da98	45285854-dcb2-4d00-9773-ed83b1edc695	technician.approve	technician	ff7fa15e-6118-4cc5-9939-5d1e34799898	\N	45.119.30.85	2026-08-29 06:45:14.2231+00
5ec5e907-a807-429b-96b2-998be9f4b2ed	45285854-dcb2-4d00-9773-ed83b1edc695	technician.approve	technician	e9977c7e-f0a5-4284-95a6-f535a31b0c9f	\N	45.119.30.85	2026-08-29 07:21:03.217433+00
6e3dfdc7-3af2-4a52-b327-ce348758be7f	45285854-dcb2-4d00-9773-ed83b1edc695	technician.approve	technician	56e6825f-1d28-4030-9831-8179f43ed3a8	\N	45.119.30.85	2026-08-29 08:09:27.019173+00
\.


--
-- Data for Name: booking_estimate_items; Type: TABLE DATA; Schema: public; Owner: homefix_db_wuc1_user
--

COPY public.booking_estimate_items (id, estimate_id, item_type, name, quantity, unit_price, amount) FROM stdin;
\.


--
-- Data for Name: booking_estimates; Type: TABLE DATA; Schema: public; Owner: homefix_db_wuc1_user
--

COPY public.booking_estimates (id, booking_id, technician_id, status, labour_amount, parts_amount, total_amount, note, customer_note, created_at, decided_at, updated_at) FROM stdin;
\.


--
-- Data for Name: booking_job_photos; Type: TABLE DATA; Schema: public; Owner: homefix_db_wuc1_user
--

COPY public.booking_job_photos (id, booking_id, technician_id, photo_type, image_url, caption, created_at) FROM stdin;
\.


--
-- Data for Name: booking_messages; Type: TABLE DATA; Schema: public; Owner: homefix_db_wuc1_user
--

COPY public.booking_messages (id, booking_id, sender_id, sender_role, content, created_at) FROM stdin;
8f050e13-1bed-43ab-b9ef-f29531a6e1fc	e70405d7-2471-42eb-b587-8f8242a67a01	3e09db72-8f82-49c5-81b4-b95be21ea46f	technician	Hello pratiksha	2026-08-29 06:50:04.209799+00
34368ac4-cb2f-48f2-9d54-7c02a7364ab8	cf08d139-b61e-40ba-b4ad-26c92233673a	4f3d12f3-d8a6-4c97-8016-2d44b252426f	customer	Hii	2026-08-29 07:53:07.195542+00
aa820898-b242-4605-8032-6b609dea97ec	cf08d139-b61e-40ba-b4ad-26c92233673a	4f3d12f3-d8a6-4c97-8016-2d44b252426f	customer	Pradnya	2026-08-29 07:53:10.371723+00
d6e33e2c-f106-444c-8734-25c14085a2c7	f4149c23-8927-400a-889e-5e8a466e38df	5978c7ed-c201-40f9-ac16-08fcb5d81431	customer	Helloo	2026-08-29 08:05:56.702912+00
7947631e-bef2-4505-9e09-2fa129eb6225	9db1257c-e883-4d18-b922-5e88d366e304	5978c7ed-c201-40f9-ac16-08fcb5d81431	customer	Hii8i	2026-08-29 08:34:49.782999+00
9450ffa7-ed66-47a5-8f4a-36cae670a0d4	b5812643-16d6-4b05-b6d8-e8f14a9d8b29	4f3d12f3-d8a6-4c97-8016-2d44b252426f	customer	Heyyy	2026-08-29 08:42:03.510127+00
9398203a-02c6-464e-88d5-f2f16f7285f6	b5812643-16d6-4b05-b6d8-e8f14a9d8b29	a5bcbdcb-965d-4e7e-843b-7e16cfd43eb4	technician	Heyy	2026-08-29 09:30:59.098364+00
3b2f9def-a30d-416f-be48-c295fd8830cc	dad82ade-9ea9-4256-9005-988faba26cba	aebfbed2-7205-437b-9045-65d1b0240e6a	customer	Hiii	2026-08-30 18:20:03.129607+00
31f6c64b-e596-4269-8c17-b1fb4de39f87	fd7da0bc-0c12-4140-b6fa-b74bbd7e714c	a5bcbdcb-965d-4e7e-843b-7e16cfd43eb4	technician	Hii	2026-08-30 18:20:33.298657+00
404ef2f8-ec58-415d-8ac8-6dee5385d7e4	fd7da0bc-0c12-4140-b6fa-b74bbd7e714c	a5bcbdcb-965d-4e7e-843b-7e16cfd43eb4	technician	Hii	2026-08-30 18:20:58.083646+00
b05da20a-9962-4e24-a1b7-3d750e9bb96d	144a9b77-35dd-48ca-ac63-d4fa3c2b8d1a	aebfbed2-7205-437b-9045-65d1b0240e6a	customer	Hiii	2026-08-31 03:03:56.603592+00
47dd26bf-a47f-4e45-a73a-4ab9b7c71798	56170d9e-66d0-4cf4-a346-eb76cec2856b	aebfbed2-7205-437b-9045-65d1b0240e6a	customer	Hiiii	2026-08-31 09:06:33.084424+00
cd0e1dfc-9d13-44c5-a01d-cf241e80fe4c	56170d9e-66d0-4cf4-a346-eb76cec2856b	35bb12a9-b2c6-4f77-b383-307759714318	technician	Hello	2026-08-31 09:06:48.413726+00
efe62009-5a47-4a63-9a9d-0163ea935db0	9640544d-5c9f-4d3f-a1a4-ec751bd6e1bd	35bb12a9-b2c6-4f77-b383-307759714318	technician	Hii	2026-08-31 17:37:57.480711+00
8607181f-391e-4267-894f-e44cd6185c65	9640544d-5c9f-4d3f-a1a4-ec751bd6e1bd	aebfbed2-7205-437b-9045-65d1b0240e6a	customer	Hiii	2026-08-31 17:38:16.881573+00
f9cc77e1-5d41-4195-81db-103066fe9f9d	a0346c66-f6c1-466e-8f6d-4fd61c501153	a5bcbdcb-965d-4e7e-843b-7e16cfd43eb4	technician	Hello	2026-09-01 11:28:55.036204+00
158e9eff-7db6-41c1-8f0f-b990fa1abddf	a0346c66-f6c1-466e-8f6d-4fd61c501153	064fad8e-000a-4ed1-a447-160afea13815	customer	Hiiiiii	2026-09-01 11:29:10.513323+00
8fa679ee-dafd-4bfe-8a15-4ab9b4ac51ee	a0346c66-f6c1-466e-8f6d-4fd61c501153	064fad8e-000a-4ed1-a447-160afea13815	customer	Hii	2026-09-01 11:29:13.263992+00
f571d64c-b374-4f97-9787-5c01398ee0a5	a0346c66-f6c1-466e-8f6d-4fd61c501153	a5bcbdcb-965d-4e7e-843b-7e16cfd43eb4	technician	Yup	2026-09-01 11:29:20.978947+00
0ee6aa82-4c16-4420-9437-236ec5f3b99a	053e8dfd-cfb9-470d-995c-be55481732e0	aebfbed2-7205-437b-9045-65d1b0240e6a	customer	Hiiiii	2026-09-03 11:41:39.092078+00
f58dcddb-27a6-490a-89ab-d568b9acddb5	053e8dfd-cfb9-470d-995c-be55481732e0	35bb12a9-b2c6-4f77-b383-307759714318	technician	Hiiiiiii	2026-09-03 11:41:47.953126+00
61487029-01c2-4c4b-a86a-8c8f67566be0	e7cfec2d-65be-4642-9512-30a6fde5df38	35bb12a9-b2c6-4f77-b383-307759714318	technician	Hiii	2026-09-04 07:05:46.446434+00
11010fa1-5c3c-468d-8ff7-58e0c8aa6e23	1ac4424a-57da-4946-adf8-3260b1dcfe3c	aebfbed2-7205-437b-9045-65d1b0240e6a	customer	Hiii	2026-09-04 07:20:51.084524+00
b1278f65-081c-494d-8d8b-e24e6702c276	1ac4424a-57da-4946-adf8-3260b1dcfe3c	35bb12a9-b2c6-4f77-b383-307759714318	technician	Hiiiii	2026-09-04 07:21:09.492676+00
56ba2e19-06f3-437a-b8bf-fd4812643396	1ac4424a-57da-4946-adf8-3260b1dcfe3c	aebfbed2-7205-437b-9045-65d1b0240e6a	customer	Hiiii	2026-09-04 07:27:22.561461+00
267226bb-c0ee-4769-aac0-6deb90fdbbed	1ac4424a-57da-4946-adf8-3260b1dcfe3c	aebfbed2-7205-437b-9045-65d1b0240e6a	customer	Hiii	2026-09-04 07:30:26.249611+00
953aede1-69c4-426b-bd82-bc89fcff7856	1ac4424a-57da-4946-adf8-3260b1dcfe3c	35bb12a9-b2c6-4f77-b383-307759714318	technician	Hiii	2026-09-04 07:49:12.528057+00
042554c3-3169-4096-aeac-b3c8d54142af	1ac4424a-57da-4946-adf8-3260b1dcfe3c	aebfbed2-7205-437b-9045-65d1b0240e6a	customer	Hiii	2026-09-04 07:53:10.178963+00
2a39284d-7fec-4afb-a372-89fcf6c5bedc	9a8facc2-f8c9-4721-aebb-45615a91aa2d	aebfbed2-7205-437b-9045-65d1b0240e6a	customer	Hii	2026-09-07 06:41:45.242295+00
\.


--
-- Data for Name: booking_status_history; Type: TABLE DATA; Schema: public; Owner: homefix_db_wuc1_user
--

COPY public.booking_status_history (id, booking_id, status, note, created_at) FROM stdin;
d2b86eff-96ac-4f6e-9195-e227c23b05df	e70405d7-2471-42eb-b587-8f8242a67a01	requested	Booking created	2026-08-29 06:47:01.040704+00
d781cc11-2394-485a-bd04-3b509414bfc4	e70405d7-2471-42eb-b587-8f8242a67a01	accepted	Technician assigned	2026-08-29 06:47:01.04693+00
3b001cc7-4738-4f33-8dbc-40e3d6e98ee5	e70405d7-2471-42eb-b587-8f8242a67a01	in_progress	Technician started the job	2026-08-29 06:47:37.898464+00
4cd93c52-c843-4251-8338-83f5c5f1750c	e70405d7-2471-42eb-b587-8f8242a67a01	completed	Job completed	2026-08-29 06:47:45.217905+00
cbbbf8d7-8363-4881-b8ad-701b342e8dfc	5d859f37-e87a-4369-8d52-1c94d9f837d5	requested	Booking created	2026-08-29 07:05:18.250454+00
2f61e8be-835a-441c-b774-5ed0d08510b5	5d859f37-e87a-4369-8d52-1c94d9f837d5	accepted	Technician assigned	2026-08-29 07:05:18.255522+00
3d00fdc2-f95c-4936-9374-fbfccc09b08f	5d859f37-e87a-4369-8d52-1c94d9f837d5	in_progress	Technician started the job	2026-08-29 07:13:42.982333+00
ce4b9f1e-563b-4125-9a8c-e82b71d9e8a4	5d859f37-e87a-4369-8d52-1c94d9f837d5	completed	Job completed	2026-08-29 07:13:48.91953+00
7a83c324-e0ce-493c-8d13-60171b90d9be	6159f686-4eca-4829-8984-8d748016d126	requested	Booking created	2026-08-29 07:21:49.272738+00
42a3a779-5753-4a35-ad80-bae48d09859c	6159f686-4eca-4829-8984-8d748016d126	accepted	Technician assigned	2026-08-29 07:21:49.278164+00
9dcc14f8-30d4-4316-8972-128f7a953543	6159f686-4eca-4829-8984-8d748016d126	in_progress	Technician started the job	2026-08-29 07:22:02.200358+00
ebbff73f-3c4d-4536-87fd-7b1961dd6f27	6159f686-4eca-4829-8984-8d748016d126	completed	Job completed	2026-08-29 07:22:10.425073+00
4914401c-5fed-42a2-90ca-6406318bf67b	cf08d139-b61e-40ba-b4ad-26c92233673a	requested	Booking created	2026-08-29 07:52:30.987566+00
4cb8ac96-2b4c-4e72-a672-74f8cbbd40fb	cf08d139-b61e-40ba-b4ad-26c92233673a	accepted	Technician assigned	2026-08-29 07:52:30.993224+00
5913d8b6-32e3-43a5-80f5-5cfb5bfb329e	f4149c23-8927-400a-889e-5e8a466e38df	requested	Booking created	2026-08-29 08:05:33.868959+00
86c554e8-76c5-4548-9db7-20a7b5e99989	f4149c23-8927-400a-889e-5e8a466e38df	accepted	Technician assigned	2026-08-29 08:05:33.872882+00
d2d5134a-40b8-4728-be08-47e98da90f1c	9db1257c-e883-4d18-b922-5e88d366e304	requested	Booking created	2026-08-29 08:34:40.522194+00
bc67a963-81a7-4511-8555-d8abd1ade884	9db1257c-e883-4d18-b922-5e88d366e304	accepted	Technician assigned	2026-08-29 08:34:40.528061+00
b83c6713-b29b-47e3-85f8-9ab3ff94cfca	b5812643-16d6-4b05-b6d8-e8f14a9d8b29	requested	Booking created	2026-08-29 08:41:53.240637+00
82131e56-7777-4b81-8d2d-f67f768a4d2e	b5812643-16d6-4b05-b6d8-e8f14a9d8b29	accepted	Technician assigned	2026-08-29 08:41:53.245988+00
f2d74ef9-fbd5-469c-82e0-425247dcad52	26823039-9062-4987-97a8-06b71e66f580	requested	Booking created	2026-08-29 08:48:20.579049+00
f0ca48b7-079a-4b8e-a504-4f4799b6b52a	26823039-9062-4987-97a8-06b71e66f580	accepted	Technician assigned	2026-08-29 08:48:20.582446+00
74234c8c-666f-43d4-929f-7c593e3eee63	b5812643-16d6-4b05-b6d8-e8f14a9d8b29	in_progress	Technician started the job	2026-08-29 09:00:06.830569+00
02dd31bf-2a1d-4f0c-b2a2-6432933ea7dd	b5812643-16d6-4b05-b6d8-e8f14a9d8b29	completed	Job completed	2026-08-29 09:05:18.326493+00
2130e0dd-c2a9-4fae-bc0d-206d5c2464fd	08c5ea8e-e260-4e2d-b604-be16d8092334	requested	Booking created	2026-08-29 11:00:18.274136+00
ca90a196-c4df-4f5f-a35e-3b6a7a260bcb	08c5ea8e-e260-4e2d-b604-be16d8092334	accepted	Technician assigned	2026-08-29 11:00:18.282453+00
acc5eca4-2762-4f27-802d-426c082d6f50	dad82ade-9ea9-4256-9005-988faba26cba	requested	Booking created	2026-08-30 01:09:29.091393+00
ad1f6b94-300e-4d0e-8f49-272996cfd186	dad82ade-9ea9-4256-9005-988faba26cba	accepted	Technician assigned	2026-08-30 01:09:29.097301+00
48042898-7069-4758-bdb2-fa8f5d4f1299	dad82ade-9ea9-4256-9005-988faba26cba	on_the_way	Technician is on the way	2026-08-30 02:27:46.064941+00
75e2aa22-bacd-4025-8db7-3af49ba4fe0f	aca4efb5-c668-448f-8330-f4b71ae2238c	requested	Booking created	2026-08-30 02:47:22.495281+00
4985a7da-b784-4dd0-9efd-299235f6e044	aca4efb5-c668-448f-8330-f4b71ae2238c	accepted	Technician assigned	2026-08-30 02:47:22.49939+00
0f117e9e-4554-48f0-9fa9-fcddee11a207	af6067b5-d9ef-4ffe-9a18-bbe5f2589f32	requested	Booking created	2026-08-30 02:47:59.918917+00
42f72824-3da0-4911-9f18-9f20708338cc	af6067b5-d9ef-4ffe-9a18-bbe5f2589f32	accepted	Technician assigned	2026-08-30 02:47:59.922221+00
1b301332-8f31-4c91-8fcb-98ac86c1637f	ee0f264e-3679-4ff8-8c85-0e75b8793e14	requested	Booking created	2026-08-30 18:09:19.287133+00
b1e36e36-25a6-404f-b938-9b1ec1fc53ae	ee0f264e-3679-4ff8-8c85-0e75b8793e14	accepted	Technician assigned	2026-08-30 18:09:19.291779+00
dc7c78e5-1fd5-43d7-a1af-356cdabf9e60	68bc8edb-976c-4030-bc76-89486f0ea45c	requested	Booking created	2026-08-30 18:17:25.35506+00
15b89522-34d8-4d12-80de-70550debe57e	68bc8edb-976c-4030-bc76-89486f0ea45c	accepted	Technician assigned	2026-08-30 18:17:25.358821+00
69941bb5-be78-4d85-84bd-b36aa4b335a9	fd7da0bc-0c12-4140-b6fa-b74bbd7e714c	requested	Booking created	2026-08-30 18:18:33.156847+00
67875741-cee3-48fe-8d6b-92deb3bf064c	fd7da0bc-0c12-4140-b6fa-b74bbd7e714c	accepted	Technician assigned	2026-08-30 18:18:33.161021+00
27714883-7999-47bf-99d9-3246d6272bea	fd7da0bc-0c12-4140-b6fa-b74bbd7e714c	on_the_way	Technician is on the way	2026-08-30 18:18:49.839437+00
e5ea3f30-f49a-4da7-8007-3cfd9d5d775b	fd7da0bc-0c12-4140-b6fa-b74bbd7e714c	cancelled	fjgh yjjg	2026-08-30 18:19:12.223687+00
1992220a-ce30-4544-b901-6fd69fd7f738	68bc8edb-976c-4030-bc76-89486f0ea45c	on_the_way	Technician is on the way	2026-08-30 18:19:26.483095+00
66159f32-f141-4efa-969e-c9f7eb446b32	144a9b77-35dd-48ca-ac63-d4fa3c2b8d1a	requested	Booking created	2026-08-31 03:02:58.25162+00
f7c7f931-097a-46d6-ba5d-7e137e9dd074	144a9b77-35dd-48ca-ac63-d4fa3c2b8d1a	accepted	Technician assigned	2026-08-31 03:02:58.258514+00
de40332d-2d73-4a9a-98f9-36e3ebb8db56	144a9b77-35dd-48ca-ac63-d4fa3c2b8d1a	on_the_way	Technician is on the way	2026-08-31 03:03:11.486036+00
8f108e65-9bf1-456c-afea-a9c25e883124	74bbd88d-6558-400a-be33-5babcc7a841b	requested	Booking created	2026-08-31 04:57:25.893447+00
84dd8e93-3a8a-42ce-8443-72cb58c1e36d	74bbd88d-6558-400a-be33-5babcc7a841b	accepted	Technician assigned	2026-08-31 04:57:25.901461+00
aa1b1c78-da2f-47b3-b534-3fa29d1e4a19	74bbd88d-6558-400a-be33-5babcc7a841b	on_the_way	Technician is on the way	2026-08-31 04:57:32.95836+00
e081cf82-5af0-41a4-80a8-afca6a17e21f	9ecf2820-25fb-46c3-9429-8ba10e59398e	requested	Booking created	2026-08-31 05:08:00.403263+00
1fe0d5cf-a39f-48d9-852e-70b30496b58c	9ecf2820-25fb-46c3-9429-8ba10e59398e	accepted	Technician assigned	2026-08-31 05:08:00.409275+00
5e177962-ac2e-43f2-ae89-c7cda7e743cb	74bbd88d-6558-400a-be33-5babcc7a841b	arrived	Technician has arrived	2026-08-31 05:09:13.748984+00
31973e2b-12af-4258-88f9-81d144e5f797	74bbd88d-6558-400a-be33-5babcc7a841b	arrived	Technician has arrived	2026-08-31 05:09:20.63317+00
6fd44942-4615-4d7e-abbd-0e4ccd106189	97804867-d6df-4dcb-9ab4-458d025d57b0	requested	Booking created	2026-08-31 05:30:56.967442+00
0b91ddba-1892-428b-b6d5-a6b6ee8484de	97804867-d6df-4dcb-9ab4-458d025d57b0	accepted	Technician assigned	2026-08-31 05:30:56.971291+00
a883405b-3623-4199-8289-f243125ff39e	97804867-d6df-4dcb-9ab4-458d025d57b0	on_the_way	Technician is on the way	2026-08-31 05:31:17.999147+00
6f89373d-db40-41a3-9206-e6d020aaffb9	57538146-3db7-4baa-b383-090b36ab505e	requested	Booking created	2026-08-31 05:32:27.027596+00
a0ecf300-9653-46eb-8fab-f51bfe1e7628	57538146-3db7-4baa-b383-090b36ab505e	accepted	Technician assigned	2026-08-31 05:32:27.030477+00
dd626a5d-a0a5-4cd4-8a12-c098a01ed4cc	57538146-3db7-4baa-b383-090b36ab505e	on_the_way	Technician is on the way	2026-08-31 05:32:31.66904+00
b9cf25bd-8d81-4e81-bc6a-269241a94149	57538146-3db7-4baa-b383-090b36ab505e	arrived	Technician has arrived	2026-08-31 05:32:41.142125+00
0a57dd2e-11a2-423e-b8a6-7134be9c306a	0a5791e9-c5bc-42b4-96d0-530df2bc92b1	requested	Booking created	2026-08-31 05:39:14.673761+00
669cf839-4c3a-40e5-b21a-aa59f649d35c	0a5791e9-c5bc-42b4-96d0-530df2bc92b1	accepted	Technician assigned	2026-08-31 05:39:14.677835+00
5d34a15b-ebb0-49b7-b12d-9998a46bf6e7	0a5791e9-c5bc-42b4-96d0-530df2bc92b1	on_the_way	Technician is on the way	2026-08-31 05:39:19.78801+00
268f0448-e4b8-47c6-98ea-b88dc154a1af	0a5791e9-c5bc-42b4-96d0-530df2bc92b1	arrived	Technician has arrived	2026-08-31 05:39:23.043262+00
582c76ec-386c-4cba-8252-75473996d61e	0a5791e9-c5bc-42b4-96d0-530df2bc92b1	arrived	Technician has arrived	2026-08-31 05:39:30.026146+00
c1949cb4-27e9-44ab-a226-404b5545d01d	0a5791e9-c5bc-42b4-96d0-530df2bc92b1	arrived	Technician has arrived	2026-08-31 05:39:36.357572+00
1302a633-0c38-4ab5-a1bc-3f480b00c3e5	0a5791e9-c5bc-42b4-96d0-530df2bc92b1	arrived	Technician has arrived	2026-08-31 05:39:52.012514+00
18cfba97-9037-4c2d-9950-2ae32998e16c	0a5791e9-c5bc-42b4-96d0-530df2bc92b1	arrived	Technician has arrived	2026-08-31 05:39:58.671135+00
a6f03b1a-ed5c-4e28-b180-501571ed171a	0a5791e9-c5bc-42b4-96d0-530df2bc92b1	arrived	Technician has arrived	2026-08-31 05:44:12.009512+00
ff76e8c4-f9e1-4789-9c00-d72c9bd1744a	0a5791e9-c5bc-42b4-96d0-530df2bc92b1	arrived	Technician has arrived	2026-08-31 05:51:12.57024+00
e1e3cf03-ff13-469e-baf5-db7b06a5778e	8bf61946-c99c-4096-a1f4-4f7184b454eb	requested	Booking created	2026-08-31 05:51:41.420522+00
f9df560e-2216-4ba9-b8bd-17042bfcd554	8bf61946-c99c-4096-a1f4-4f7184b454eb	accepted	Technician assigned	2026-08-31 05:51:41.425038+00
6c899111-47e9-4ad9-a821-6fc2cf1086bf	8bf61946-c99c-4096-a1f4-4f7184b454eb	on_the_way	Technician is on the way	2026-08-31 05:51:51.285936+00
11af0075-affb-4d11-8121-dac718e6c879	8bf61946-c99c-4096-a1f4-4f7184b454eb	arrived	Technician has arrived	2026-08-31 05:51:52.192132+00
781a38f7-2cb2-4625-9312-338b5e955e4c	bdd5c7c5-4dff-49ba-85ab-25045ee16276	requested	Booking created	2026-08-31 06:07:21.062253+00
c342ef01-4ce7-46f1-a690-5ef4e7f1ee80	bdd5c7c5-4dff-49ba-85ab-25045ee16276	accepted	Technician assigned	2026-08-31 06:07:21.06938+00
966e05c6-4e9e-473d-a494-ff7006c70163	bdd5c7c5-4dff-49ba-85ab-25045ee16276	on_the_way	Technician is on the way	2026-08-31 06:07:26.424599+00
4fd4c00f-60c9-411c-9cfb-fe3adb25405c	bdd5c7c5-4dff-49ba-85ab-25045ee16276	arrived	Technician has arrived	2026-08-31 06:07:29.092167+00
36a0fb25-9fc4-47e0-a156-4204e2a63a28	f6d1c69c-8a4a-4a40-af39-4217a4c404b8	requested	Booking created	2026-08-31 06:22:16.917007+00
8a52838b-4294-490b-bbc4-b3f2c120f0ba	f6d1c69c-8a4a-4a40-af39-4217a4c404b8	accepted	Technician assigned	2026-08-31 06:22:16.92155+00
b7027fd0-3c0e-4f0e-935b-e4a6b7e6f000	f6d1c69c-8a4a-4a40-af39-4217a4c404b8	on_the_way	Technician is on the way	2026-08-31 06:22:21.401884+00
57803b31-16f7-4eca-ae3e-715ac10ed6a6	f6d1c69c-8a4a-4a40-af39-4217a4c404b8	arrived	Technician has arrived	2026-08-31 06:22:22.237139+00
a3581dc1-e98a-4917-94d8-5628f01a80e1	98b8c4e5-0939-44ee-a66e-8c069d3f110a	requested	Booking created	2026-08-31 06:26:59.096186+00
5fe9cbe9-8f5a-4191-beba-801aa6b14d04	98b8c4e5-0939-44ee-a66e-8c069d3f110a	accepted	Technician assigned	2026-08-31 06:26:59.19636+00
0170db65-8715-4c4e-9330-6f8e9996b5ab	98b8c4e5-0939-44ee-a66e-8c069d3f110a	on_the_way	Technician is on the way	2026-08-31 06:27:04.574665+00
f94728a3-1ccf-42a9-9b25-0cfa526bb4df	98b8c4e5-0939-44ee-a66e-8c069d3f110a	arrived	Technician has arrived	2026-08-31 06:27:06.725353+00
a3fbb480-a6a9-4e38-a893-b47c012a5214	61e186b5-63fa-457a-a56c-3789f77e8e79	requested	Booking created	2026-08-31 06:29:31.044308+00
174d432b-be84-4959-9e91-9854581eb502	61e186b5-63fa-457a-a56c-3789f77e8e79	accepted	Technician assigned	2026-08-31 06:29:31.04749+00
000c2084-a402-4e63-8adf-d219886c5c2c	61e186b5-63fa-457a-a56c-3789f77e8e79	on_the_way	Technician is on the way	2026-08-31 06:29:37.228625+00
42c2ce1b-4048-48b9-a6fe-6e232d8f7211	61e186b5-63fa-457a-a56c-3789f77e8e79	arrived	Technician has arrived	2026-08-31 06:29:40.280392+00
7a426e25-5298-4e9d-b39e-a111551d93b2	38839d69-9794-4989-95a0-2fb767af3575	requested	Booking created	2026-08-31 06:42:33.43292+00
630c4812-6aa2-4a31-833d-0300cbd527fe	38839d69-9794-4989-95a0-2fb767af3575	accepted	Technician assigned	2026-08-31 06:42:33.440056+00
5ae2614f-6382-4528-a461-1318bc1e1619	38839d69-9794-4989-95a0-2fb767af3575	on_the_way	Technician is on the way	2026-08-31 06:42:38.258323+00
4e73b0cb-712d-4c44-b8e3-174ac5f6e949	38839d69-9794-4989-95a0-2fb767af3575	arrived	Technician has arrived	2026-08-31 06:42:39.092141+00
1f431706-0b0d-4ded-8a2f-4f3c7e89d24c	341036e8-d595-4979-b2f5-346bc5f02962	requested	Booking created	2026-08-31 06:52:54.177571+00
713a4351-0fa3-4562-b770-801f3635a3e0	341036e8-d595-4979-b2f5-346bc5f02962	accepted	Technician assigned	2026-08-31 06:52:54.181218+00
2a9c29fa-d151-4d8d-9a12-fbde800157c0	341036e8-d595-4979-b2f5-346bc5f02962	on_the_way	Technician is on the way	2026-08-31 06:52:57.902549+00
ed1a4a58-2222-453f-b91d-2578bd0f570d	341036e8-d595-4979-b2f5-346bc5f02962	arrived	Technician has arrived	2026-08-31 06:52:59.472068+00
41b7ef77-f038-4b19-9fdb-ee80b64e8efb	341036e8-d595-4979-b2f5-346bc5f02962	inspecting	OTP verified, service started	2026-08-31 06:53:08.822201+00
2a8d718f-a347-4118-a43a-93fdcf45de09	a7a39d1e-27f4-4855-9a21-3132d0dbbddc	requested	Booking created	2026-08-31 06:55:08.980474+00
6dd6b1b4-4c68-4a08-8335-734123cd44c9	a7a39d1e-27f4-4855-9a21-3132d0dbbddc	accepted	Technician assigned	2026-08-31 06:55:09.009081+00
18743ace-e849-4810-b013-7b46b915afcd	a7a39d1e-27f4-4855-9a21-3132d0dbbddc	on_the_way	Technician is on the way	2026-08-31 06:55:13.5629+00
f989d925-ffce-4e82-863e-6bc6e7d6cf38	a7a39d1e-27f4-4855-9a21-3132d0dbbddc	arrived	Technician has arrived	2026-08-31 06:55:14.855211+00
91d8d3ec-001f-40c1-83a9-e74ceece46f0	a7a39d1e-27f4-4855-9a21-3132d0dbbddc	inspecting	OTP verified, service started	2026-08-31 06:55:24.124056+00
45295adf-a645-452f-ae43-b68a011429ce	ebfcf350-dcd8-498d-b0c7-bab5ea2b6408	requested	Booking created	2026-08-31 06:59:27.618004+00
0cdb15c9-c361-4f41-883f-bd8ae9c8a826	ebfcf350-dcd8-498d-b0c7-bab5ea2b6408	accepted	Technician assigned	2026-08-31 06:59:27.623435+00
ee607615-c384-4126-ba8d-13bdc81ea395	ebfcf350-dcd8-498d-b0c7-bab5ea2b6408	on_the_way	Technician is on the way	2026-08-31 06:59:34.110455+00
13ab3ed2-2412-4d42-8a5e-cb93e3d00013	ebfcf350-dcd8-498d-b0c7-bab5ea2b6408	arrived	Technician has arrived	2026-08-31 06:59:34.938263+00
26a2c81d-917e-4701-8bd4-ffb37b068769	ebfcf350-dcd8-498d-b0c7-bab5ea2b6408	inspecting	OTP verified, service started	2026-08-31 06:59:42.584739+00
e1233340-6e3f-4501-8f16-f4f616b02589	271820c9-e8ee-4424-abfc-ffb4ab065c02	requested	Booking created	2026-08-31 09:04:33.165134+00
9553e85b-d323-4d9b-95c3-6f51c5216f21	271820c9-e8ee-4424-abfc-ffb4ab065c02	accepted	Technician assigned	2026-08-31 09:04:33.172267+00
8a104322-6eaf-4d3f-ba71-a29c3cec5b1c	271820c9-e8ee-4424-abfc-ffb4ab065c02	on_the_way	Technician is on the way	2026-08-31 09:04:41.386455+00
0a1cc37d-4a4a-4b1d-9400-3d60934e9883	271820c9-e8ee-4424-abfc-ffb4ab065c02	arrived	Technician has arrived	2026-08-31 09:04:43.498028+00
afd8f44a-78c8-4031-b420-2b3fee13a009	271820c9-e8ee-4424-abfc-ffb4ab065c02	inspecting	OTP verified, service started	2026-08-31 09:04:50.006634+00
0ba38a30-e624-44fb-9b60-0a7b213788e9	56170d9e-66d0-4cf4-a346-eb76cec2856b	requested	Booking created	2026-08-31 09:05:25.499882+00
a370d887-11b9-4b02-9059-70bd7a0b6a7f	56170d9e-66d0-4cf4-a346-eb76cec2856b	accepted	Technician assigned	2026-08-31 09:05:25.504861+00
562c3420-e250-4e2e-abe5-ac7204d91b3e	56170d9e-66d0-4cf4-a346-eb76cec2856b	on_the_way	Technician is on the way	2026-08-31 09:05:36.175286+00
b0297127-6d14-4d32-8d03-067712943155	56170d9e-66d0-4cf4-a346-eb76cec2856b	arrived	Technician has arrived	2026-08-31 09:05:36.966295+00
e80db016-34db-4248-962e-06bd70ebf06b	56170d9e-66d0-4cf4-a346-eb76cec2856b	inspecting	OTP verified, service started	2026-08-31 09:05:41.620154+00
49c04f81-6098-4c71-be3a-1ce4e2535afe	9640544d-5c9f-4d3f-a1a4-ec751bd6e1bd	requested	Booking created	2026-08-31 17:26:30.050888+00
e1a8f3ea-b2b3-4759-a820-cf7ab32bac83	9640544d-5c9f-4d3f-a1a4-ec751bd6e1bd	accepted	Technician assigned	2026-08-31 17:26:30.055632+00
1a9c8b3b-c8a4-4de3-9df8-45fc434b247c	9640544d-5c9f-4d3f-a1a4-ec751bd6e1bd	on_the_way	Technician is on the way	2026-08-31 17:26:39.302353+00
2d56be00-ac61-4666-a54f-e0a216e64d2e	9640544d-5c9f-4d3f-a1a4-ec751bd6e1bd	arrived	Technician has arrived	2026-08-31 17:26:42.387803+00
ac164ec0-cf2b-4da8-8fb9-5869313b23f4	9640544d-5c9f-4d3f-a1a4-ec751bd6e1bd	inspecting	OTP verified, service started	2026-08-31 17:26:49.091906+00
64303fb2-f68f-4585-bead-84e7ef6791e2	1f64b5e0-817e-435b-b7f3-c2d8b1df47e7	requested	Booking created	2026-09-01 03:09:36.001133+00
25603485-0f02-439a-9169-1ae249aad09e	1f64b5e0-817e-435b-b7f3-c2d8b1df47e7	accepted	Technician assigned	2026-09-01 03:09:36.013588+00
9acf50a8-2bff-400b-bc46-ae14d5d0910c	1f64b5e0-817e-435b-b7f3-c2d8b1df47e7	on_the_way	Technician is on the way	2026-09-01 03:09:42.371765+00
6c68bbd3-723f-437c-84c7-8e086fc7536d	1f64b5e0-817e-435b-b7f3-c2d8b1df47e7	arrived	Technician has arrived	2026-09-01 03:09:44.127112+00
a20709c3-f4d9-46b5-baf3-3e808c508688	1f64b5e0-817e-435b-b7f3-c2d8b1df47e7	inspecting	OTP verified, service started	2026-09-01 03:09:49.099884+00
da24407e-02e1-48b7-a515-f06aa627436f	86bea55f-a33f-4450-9cf6-23534d9976e5	requested	Booking created	2026-09-01 06:06:44.535026+00
5c6720d7-d709-4ad2-b97b-8cbafe1209c2	86bea55f-a33f-4450-9cf6-23534d9976e5	accepted	Technician assigned	2026-09-01 06:06:44.542249+00
c31f2579-c2a8-47d0-9777-94aad940829b	94f58d5b-b308-4537-9d2b-6c444a60e310	requested	Booking created	2026-09-01 06:23:19.076725+00
0158d6ba-f3f5-4792-9185-385aec8038cb	94f58d5b-b308-4537-9d2b-6c444a60e310	accepted	Technician assigned	2026-09-01 06:23:19.09913+00
873bf83c-374d-4a59-af83-39f61a1fcb7d	94f58d5b-b308-4537-9d2b-6c444a60e310	on_the_way	Technician is on the way	2026-09-01 06:23:29.721351+00
2cebdf84-4235-48ad-bf74-175bd3c7130b	94f58d5b-b308-4537-9d2b-6c444a60e310	on_the_way	Technician is on the way	2026-09-01 06:23:34.214843+00
fd28d8d3-edf8-4436-a620-6fb53466c76a	94f58d5b-b308-4537-9d2b-6c444a60e310	on_the_way	Technician is on the way	2026-09-01 06:23:35.213732+00
9bb453e8-0fe3-46b2-8bee-627f33bf23c7	94f58d5b-b308-4537-9d2b-6c444a60e310	on_the_way	Technician is on the way	2026-09-01 06:23:35.823466+00
eb7cc0e6-12a3-4468-a337-c8dc9e55dd5e	94f58d5b-b308-4537-9d2b-6c444a60e310	on_the_way	Technician is on the way	2026-09-01 06:23:36.30609+00
d3766b2d-c098-4309-ade6-9637fb3ba48e	94f58d5b-b308-4537-9d2b-6c444a60e310	arrived	Technician has arrived	2026-09-01 06:23:38.727262+00
16932e3a-7674-4c8b-bdb7-d345d5dd9ca6	94f58d5b-b308-4537-9d2b-6c444a60e310	inspecting	OTP verified, service started	2026-09-01 06:23:45.328258+00
0dc39551-4714-4d27-9e47-a8fe4f4409ac	dd974c8f-062c-47e0-9079-945a264c324e	requested	Booking created	2026-09-01 07:00:59.225828+00
9367700a-c08c-4330-b4f6-44af2b1ec6af	dd974c8f-062c-47e0-9079-945a264c324e	accepted	Technician assigned	2026-09-01 07:00:59.232164+00
d6e86abe-c5c3-4d97-ace7-91f0bea594c5	f95e9d73-b233-4478-a084-8297a5a0b17d	requested	Booking created	2026-09-01 07:14:40.151461+00
ec264c46-b230-451f-acf5-6a1261f84f8d	f95e9d73-b233-4478-a084-8297a5a0b17d	accepted	Technician assigned	2026-09-01 07:14:40.161824+00
38b22dd1-113d-4a13-9f69-be3e24c55497	de9638e9-bfe9-471d-b91e-908706f4e6d1	requested	Booking created	2026-09-01 07:16:32.205064+00
fae7667b-b641-43e9-b460-71b80177a00b	de9638e9-bfe9-471d-b91e-908706f4e6d1	accepted	Technician assigned	2026-09-01 07:16:32.213041+00
76011e83-72de-48c3-b69e-e5ce9d88e580	de9638e9-bfe9-471d-b91e-908706f4e6d1	cancelled	hjioo	2026-09-01 07:16:40.315974+00
ffc8d301-3a39-45b5-a1fd-7e58f8e1c5be	d6919e1e-3713-4ba7-aa47-852d496da26a	requested	Booking created	2026-09-01 10:48:25.334461+00
efc6f058-1791-45a6-8ea0-c4ba1fa8ca53	d6919e1e-3713-4ba7-aa47-852d496da26a	accepted	Technician assigned	2026-09-01 10:48:25.340151+00
b870026a-3688-4c15-815b-362dd3d5a522	45de7d89-bd38-40c8-8735-f99d6c67a674	requested	Booking created	2026-09-01 10:59:11.924597+00
b7d8221d-4074-4880-b6b5-e67c86474a3a	45de7d89-bd38-40c8-8735-f99d6c67a674	accepted	Technician assigned	2026-09-01 10:59:11.928742+00
7b11494a-dbfd-48db-ba4a-5210eff1e7c3	45de7d89-bd38-40c8-8735-f99d6c67a674	on_the_way	Technician is on the way	2026-09-01 10:59:17.827423+00
8e5e0e5f-27b2-481a-bce2-4558a38b4d00	45de7d89-bd38-40c8-8735-f99d6c67a674	arrived	Technician has arrived	2026-09-01 10:59:19.533175+00
5f5cbdd8-2097-48f3-ae3d-906f38411ae5	45de7d89-bd38-40c8-8735-f99d6c67a674	inspecting	OTP verified, service started	2026-09-01 10:59:28.866089+00
83401b7e-780b-4ae7-8c23-6e80add084a8	edf7d099-aeb6-4acf-9e19-fad995abfb96	requested	Booking created	2026-09-01 11:22:58.995365+00
5ca39639-b28f-4da6-b9d1-c19fd3481967	edf7d099-aeb6-4acf-9e19-fad995abfb96	accepted	Technician assigned	2026-09-01 11:22:59.09147+00
c4917166-3e07-4ba3-bc06-a5932993a20b	a0346c66-f6c1-466e-8f6d-4fd61c501153	requested	Booking created	2026-09-01 11:23:41.515669+00
4d2d07b7-63a8-4bcf-9b1c-8cc3323816f2	a0346c66-f6c1-466e-8f6d-4fd61c501153	accepted	Technician assigned	2026-09-01 11:23:41.521908+00
97a0cee3-b8c7-419d-ad23-f6d29eb9d1b3	a0346c66-f6c1-466e-8f6d-4fd61c501153	on_the_way	Technician is on the way	2026-09-01 11:23:45.921793+00
bcbe2f4a-2fa5-40e8-a6d8-34712a1092fc	a0346c66-f6c1-466e-8f6d-4fd61c501153	arrived	Technician has arrived	2026-09-01 11:23:46.664515+00
f2d83021-586e-4eeb-a0ed-5be03e958f89	a0346c66-f6c1-466e-8f6d-4fd61c501153	inspecting	OTP verified, service started	2026-09-01 11:23:52.18512+00
e1dba73d-b810-417b-a1f4-1b13a84995ad	ad934dd3-d075-4515-8acf-92c82c2b0e6d	requested	Booking created	2026-09-02 04:47:07.362217+00
be63df7c-3d04-4dc5-8156-95f3da379a67	ad934dd3-d075-4515-8acf-92c82c2b0e6d	accepted	Technician assigned	2026-09-02 04:47:07.370796+00
edf9bfa6-f50a-440e-a46a-4c92342bf4cc	b16efaa0-4d95-4044-b794-62e407559ac6	requested	Booking created	2026-09-02 04:47:31.819604+00
521f7778-fbb0-4848-9d1c-d763c672e78f	b16efaa0-4d95-4044-b794-62e407559ac6	accepted	Technician assigned	2026-09-02 04:47:31.829166+00
541f6ed9-192a-4fb3-ba05-c11f44098c23	b16efaa0-4d95-4044-b794-62e407559ac6	cancelled	report an issue	2026-09-02 04:49:39.092367+00
db6b20e8-b785-471e-aed4-a5a5eb868c04	92ebb125-533e-4092-a72f-3d7d1a850b72	requested	Booking created	2026-09-02 04:52:51.856466+00
bb1d35de-bc29-4282-a420-cc327b89dded	92ebb125-533e-4092-a72f-3d7d1a850b72	accepted	Technician assigned	2026-09-02 04:52:51.860343+00
02e9cef4-fee2-469e-a9c4-09aaf54de745	ad934dd3-d075-4515-8acf-92c82c2b0e6d	cancelled	fgghjiii	2026-09-02 04:53:05.627767+00
cfd98bba-5372-4a63-8e3f-8ee1442ff3fb	edf7d099-aeb6-4acf-9e19-fad995abfb96	cancelled	guiigff	2026-09-02 05:20:12.502873+00
4cf5cc76-4b0b-4af9-9b90-8dd2130db032	3e55eab3-e739-46dd-94aa-48293f7b4663	requested	Booking created	2026-09-02 07:01:29.904764+00
19fa6044-9ff4-443f-a19a-eda4ee351323	3e55eab3-e739-46dd-94aa-48293f7b4663	accepted	Technician assigned	2026-09-02 07:01:29.911059+00
eca62101-689d-4ad0-9a71-9cab372283d8	ed453b6d-8abd-4ece-b23d-4964ddc56002	requested	Booking created	2026-09-02 07:01:48.337454+00
32e5227c-7058-4024-85c8-083ced3a67bb	ed453b6d-8abd-4ece-b23d-4964ddc56002	accepted	Technician assigned	2026-09-02 07:01:48.343555+00
df3baab1-79e0-408c-8f3c-b030f78d6d0a	069a4e97-aefb-4cc4-bfb0-ac69d75c7017	requested	Booking created	2026-09-02 07:48:50.216125+00
d83d47c9-52f5-4638-9f04-c1a534fd5e6b	069a4e97-aefb-4cc4-bfb0-ac69d75c7017	accepted	Technician assigned	2026-09-02 07:48:50.228447+00
746efee6-dcee-4f7a-b78c-e1cbfe29eb73	4a1cca6f-0c29-45a4-86fd-c6da18db7024	requested	Booking created	2026-09-02 07:53:14.278451+00
9a9caaf7-0664-4aee-8c15-658751f2ed24	4a1cca6f-0c29-45a4-86fd-c6da18db7024	accepted	Technician assigned	2026-09-02 07:53:14.284582+00
da5060f5-c7ff-4230-ab13-ef359cdb9863	21c4ac3b-8dd8-41fa-95a9-acf978333671	requested	Booking created	2026-09-02 09:09:38.637005+00
94013a23-be7a-45ec-8fde-fb1c305e83dc	21c4ac3b-8dd8-41fa-95a9-acf978333671	accepted	Technician assigned	2026-09-02 09:09:38.643621+00
2b1aa2b5-6302-43d2-a805-d2826ee1c0c2	4e3bf9f3-2f68-4892-a9d5-444ae1e3f388	requested	Booking created	2026-09-03 03:13:01.483053+00
c39bbb25-0362-4cad-96c2-ecae39da79b5	4e3bf9f3-2f68-4892-a9d5-444ae1e3f388	accepted	Technician assigned	2026-09-03 03:13:01.488993+00
4b888a50-6d2d-48ef-9fc2-0656830176d8	4e3bf9f3-2f68-4892-a9d5-444ae1e3f388	on_the_way	Technician is on the way	2026-09-03 03:13:06.077078+00
78bc56c9-df7c-404d-8b2e-b8e263d9590b	4e3bf9f3-2f68-4892-a9d5-444ae1e3f388	arrived	Technician has arrived	2026-09-03 03:13:08.479635+00
d65a2c71-eb63-43ef-adc0-8272184f3283	4e3bf9f3-2f68-4892-a9d5-444ae1e3f388	inspecting	OTP verified, service started	2026-09-03 03:13:15.027981+00
01fc1fd9-5652-4d1d-a45f-9e021af56da9	fb01b515-45a9-48ae-8126-9ff7044ebe64	requested	Booking created	2026-09-03 03:15:00.704865+00
7d0c4cb2-176a-4375-9a0c-fa2019805fc1	fb01b515-45a9-48ae-8126-9ff7044ebe64	accepted	Technician assigned	2026-09-03 03:15:00.70924+00
e3f4d9fb-a638-4182-80fe-29da9f65fd67	fb01b515-45a9-48ae-8126-9ff7044ebe64	on_the_way	Technician is on the way	2026-09-03 03:15:06.717469+00
c825acf7-7454-4a44-8c74-df8a356a6d1f	fb01b515-45a9-48ae-8126-9ff7044ebe64	arrived	Technician has arrived	2026-09-03 03:15:08.994707+00
f3d49b1b-5c0f-45a4-9e08-f0dedf535a67	de6289f8-f8c8-47c7-bfec-650c68178691	requested	Booking created	2026-09-03 03:15:26.367448+00
b6c5b3a4-d2b6-4082-914d-5232c3c66830	de6289f8-f8c8-47c7-bfec-650c68178691	accepted	Technician assigned	2026-09-03 03:15:26.379114+00
5335246b-f084-444d-9d40-79419cd0cdcb	de6289f8-f8c8-47c7-bfec-650c68178691	on_the_way	Technician is on the way	2026-09-03 03:15:29.430887+00
f62e4a6b-6158-45d5-8ef5-d39260b75098	c2e3fd6f-14b7-4147-87ff-a7f78d92592e	requested	Booking created	2026-09-03 03:17:40.594509+00
442a0d7b-c679-4c38-9650-c8e42d2f2c31	c2e3fd6f-14b7-4147-87ff-a7f78d92592e	accepted	Technician assigned	2026-09-03 03:17:40.599009+00
ab19dc81-59d4-413e-b944-00f3e90e7e4f	c2e3fd6f-14b7-4147-87ff-a7f78d92592e	on_the_way	Technician is on the way	2026-09-03 03:18:51.376374+00
20450e83-5773-4e05-b973-e5c9bc995c9f	49c23089-e873-4e38-8ce0-52da9a4f2787	requested	Booking created	2026-09-03 03:36:07.229015+00
24dc1fc2-b6d7-4edf-be95-e7fdd03c22a6	49c23089-e873-4e38-8ce0-52da9a4f2787	accepted	Technician assigned	2026-09-03 03:36:07.233035+00
b819ed3f-68d1-4e84-b2f2-86b51d284e8b	49c23089-e873-4e38-8ce0-52da9a4f2787	on_the_way	Technician is on the way	2026-09-03 03:36:12.213382+00
9973ed97-bfbe-4f80-b782-278b19e33463	49c23089-e873-4e38-8ce0-52da9a4f2787	arrived	Technician has arrived	2026-09-03 03:36:13.439337+00
cff7d544-49fb-4f65-a47c-0fb389a2c1b0	49c23089-e873-4e38-8ce0-52da9a4f2787	inspecting	OTP verified, service started	2026-09-03 03:36:20.070863+00
20bba348-5349-4962-b7ba-48d2b97c6f4b	49c23089-e873-4e38-8ce0-52da9a4f2787	completed	Job completed	2026-09-03 04:04:56.556639+00
e076f3b7-3a05-4684-92e9-b6e78229cb23	d115aac1-8291-4fff-9010-dc78e5281247	requested	Booking created	2026-09-03 04:06:03.103226+00
48eae06a-b4a4-4976-ba8b-c41bda772508	d115aac1-8291-4fff-9010-dc78e5281247	accepted	Technician assigned	2026-09-03 04:06:03.108626+00
18edcacd-24a3-4f22-8a52-9d273077395b	2041b386-bc65-469a-b8e4-10bb153d8d69	requested	Booking created	2026-09-03 05:03:08.773456+00
994e94c9-5dae-4371-baf6-eceb2c99c22a	2041b386-bc65-469a-b8e4-10bb153d8d69	accepted	Technician assigned	2026-09-03 05:03:08.783499+00
2508364e-9b65-4ad4-8783-35b5f42a2b9b	8627b7bb-ca01-484d-918d-fbd552855a4b	requested	Booking created	2026-09-03 05:32:18.169208+00
619ba0a6-7dd7-4081-864a-40b9984fe129	8627b7bb-ca01-484d-918d-fbd552855a4b	accepted	Technician assigned	2026-09-03 05:32:18.18005+00
1dbbb266-df70-4dfc-8c27-f8076f8ddf0d	619e39f7-7322-43d9-9b7f-199a6e826c67	requested	Booking created	2026-09-03 05:32:52.965267+00
6c3755c4-67fd-4bb3-8c6a-4b0b2585c23c	619e39f7-7322-43d9-9b7f-199a6e826c67	accepted	Technician assigned	2026-09-03 05:32:52.971891+00
c504e637-1ac0-49d1-99f5-7513bcf10af4	6cfc011e-04f5-422f-8f42-e4e073364b39	requested	Booking created	2026-09-03 05:33:13.001467+00
c83e299b-93a7-46e2-8c66-0ca13c1b4fa9	6cfc011e-04f5-422f-8f42-e4e073364b39	accepted	Technician assigned	2026-09-03 05:33:13.004958+00
6d32a27f-72a6-45cf-870d-7ca6fd40d43d	1b30f148-2d8f-4401-8d70-7a7d2311e88b	requested	Booking created	2026-09-03 05:37:52.825207+00
4f58ab91-62b9-4fb3-814c-db8797fab7b7	1b30f148-2d8f-4401-8d70-7a7d2311e88b	accepted	Technician assigned	2026-09-03 05:37:52.831795+00
304010a6-b444-4bd5-a11b-86d805c31086	7fa3e04d-2fba-467f-961e-55610b39ac8c	requested	Booking created	2026-09-03 05:55:09.092678+00
c53be985-a04a-4bcb-b1bf-dfdb3e2da586	7fa3e04d-2fba-467f-961e-55610b39ac8c	accepted	Technician assigned	2026-09-03 05:55:09.097949+00
cd2bb3c1-cbb3-420d-9110-b17761f36c63	82b00ea2-a795-4bde-aa78-8cd9956f14bc	requested	Booking created	2026-09-03 05:55:37.129533+00
52562434-a191-48ac-a615-32501827cdcc	82b00ea2-a795-4bde-aa78-8cd9956f14bc	accepted	Technician assigned	2026-09-03 05:55:37.133162+00
78d7b7e6-db3f-40bc-8b4c-823e2cf799ea	82b00ea2-a795-4bde-aa78-8cd9956f14bc	on_the_way	Technician is on the way	2026-09-03 06:29:27.9324+00
d29dd309-4513-4ca9-a19a-c83a9a6c438d	82b00ea2-a795-4bde-aa78-8cd9956f14bc	arrived	Technician has arrived	2026-09-03 06:29:30.36508+00
7acaf1e8-1505-46da-b74c-6eb5bddcf4b1	84bae57a-641a-4404-b616-866208e4dd33	requested	Booking created	2026-09-03 06:45:12.308454+00
a64372cd-3634-4adc-a55d-58ef7c21b0bc	84bae57a-641a-4404-b616-866208e4dd33	accepted	Technician assigned	2026-09-03 06:45:12.314474+00
69b276d4-319f-43a8-93f2-f4cac04555f6	84bae57a-641a-4404-b616-866208e4dd33	on_the_way	Technician is on the way	2026-09-03 06:45:44.947458+00
593ffc1e-f505-4b18-9ef9-91b0cccb05f7	84bae57a-641a-4404-b616-866208e4dd33	arrived	Technician has arrived	2026-09-03 06:45:46.582028+00
c8b0a3a3-a196-4655-8649-d6c3c6c8e1a5	84bae57a-641a-4404-b616-866208e4dd33	repair_in_progress	OTP verified, repair started	2026-09-03 06:46:55.058713+00
c008daa6-164d-49fb-b19a-62d842c4e164	782acec4-53bb-49b2-8795-313d35eb31ea	requested	Booking created	2026-09-03 07:15:11.33781+00
1430b4de-e451-4572-802e-85d685523889	782acec4-53bb-49b2-8795-313d35eb31ea	accepted	Technician assigned	2026-09-03 07:15:11.344334+00
84fc4e08-e8a6-4f7b-88e4-f234a86fd96d	d41d3e67-58a8-4739-b603-915c37570718	requested	Booking created	2026-09-03 07:17:52.620244+00
9a6d4ba6-1007-4dfd-ae25-ca118794d95d	d41d3e67-58a8-4739-b603-915c37570718	accepted	Technician assigned	2026-09-03 07:17:52.624251+00
57cdc7a8-2a56-4058-82a7-a04633904b47	d41d3e67-58a8-4739-b603-915c37570718	on_the_way	Technician is on the way	2026-09-03 07:17:58.299565+00
c8eeef5b-fe5b-4c01-b1c4-61c839589a11	d41d3e67-58a8-4739-b603-915c37570718	arrived	Technician has arrived	2026-09-03 07:18:00.163615+00
025a2524-a4bd-4475-b50d-47b1097e1035	56aca21f-96e2-4382-a098-5fa364070cb5	requested	Booking created	2026-09-03 07:18:14.677349+00
3f4bff3b-8aa0-4630-b904-9b18c2bf9d4f	56aca21f-96e2-4382-a098-5fa364070cb5	accepted	Technician assigned	2026-09-03 07:18:14.681456+00
22d16fbe-02dc-4eab-a053-266bafa724eb	56aca21f-96e2-4382-a098-5fa364070cb5	on_the_way	Technician is on the way	2026-09-03 07:18:19.973116+00
ac7d4766-4851-4591-bd8f-a6112b3663ce	56aca21f-96e2-4382-a098-5fa364070cb5	arrived	Technician has arrived	2026-09-03 07:18:21.027345+00
665e6b94-8d04-40db-8b99-2d53fea3edde	56aca21f-96e2-4382-a098-5fa364070cb5	repair_in_progress	OTP verified, repair started	2026-09-03 07:18:30.095747+00
29991971-c29d-45d8-8a93-ed6125a42f9b	12dd8936-488e-48c8-8312-122fb8cc53f5	requested	Booking created	2026-09-03 08:05:39.580732+00
14da7a63-a114-4c28-a7ec-403ea7f34ebb	12dd8936-488e-48c8-8312-122fb8cc53f5	accepted	Technician assigned	2026-09-03 08:05:39.586307+00
7b2cec84-e767-48fd-bf43-c1da292bb72a	12dd8936-488e-48c8-8312-122fb8cc53f5	on_the_way	Technician is on the way	2026-09-03 08:06:36.841481+00
4db217e9-4b4e-4596-a7a3-56d935a9821d	12dd8936-488e-48c8-8312-122fb8cc53f5	arrived	Technician has arrived	2026-09-03 08:06:43.375452+00
3ab7f310-8457-401e-bacd-95c2dc8ce281	12dd8936-488e-48c8-8312-122fb8cc53f5	inspecting	OTP verified, service started	2026-09-03 08:06:54.408438+00
c1b8af22-1074-417f-bb08-7537b5320347	50ed0da7-a6ef-43ce-8f40-a1f79c284c22	requested	Booking created	2026-09-03 08:08:18.95048+00
4ea7e7fc-d6b5-403b-825d-ff6c76ef8917	50ed0da7-a6ef-43ce-8f40-a1f79c284c22	accepted	Technician assigned	2026-09-03 08:08:18.955673+00
c23133b3-af66-43c1-a932-ec053ff398f5	86a89aef-ad60-4443-bd89-710892e93df4	requested	Booking created	2026-09-03 08:38:53.608872+00
7f0477d5-ba13-455e-9359-c41d131b8362	86a89aef-ad60-4443-bd89-710892e93df4	accepted	Technician assigned	2026-09-03 08:38:53.614284+00
c68da785-3cef-41ad-94af-cf9bb26fcd60	86a89aef-ad60-4443-bd89-710892e93df4	on_the_way	Technician is on the way	2026-09-03 08:39:08.290681+00
79f1e857-610f-4448-b371-0678d1a888be	bcde4eec-26b8-4c7a-b71a-bbb56a8b8c2b	requested	Booking created	2026-09-03 08:39:21.364245+00
d8fedead-c6bc-4a58-8fff-3da742c790a9	bcde4eec-26b8-4c7a-b71a-bbb56a8b8c2b	accepted	Technician assigned	2026-09-03 08:39:21.369326+00
163e566f-77c1-4d3d-ba11-274b67782bee	bcde4eec-26b8-4c7a-b71a-bbb56a8b8c2b	on_the_way	Technician is on the way	2026-09-03 08:39:30.14986+00
8d992ee8-76f3-4703-812d-2d6a24c8a8b6	bcde4eec-26b8-4c7a-b71a-bbb56a8b8c2b	arrived	Technician has arrived	2026-09-03 08:39:36.269364+00
081491fc-ea59-4767-8066-aa89514e6296	5ccde187-b272-449f-8d77-cf20b2d50540	requested	Booking created	2026-09-03 08:40:37.536012+00
1a335eee-9f7c-472e-a17d-a998d6d095dc	5ccde187-b272-449f-8d77-cf20b2d50540	accepted	Technician assigned	2026-09-03 08:40:37.539113+00
3b890271-556d-43a2-a5a3-c51f7b3437a5	bcde4eec-26b8-4c7a-b71a-bbb56a8b8c2b	inspecting	OTP verified, service started	2026-09-03 08:39:42.806731+00
0c6f0d6e-5a4e-44fa-b437-13e3fe067bac	b85f589c-990b-4905-89ab-0af5524b6001	requested	Booking created	2026-09-03 09:16:48.643496+00
53e059a5-8621-494d-b9ee-0377a89cfa30	b85f589c-990b-4905-89ab-0af5524b6001	accepted	Technician assigned	2026-09-03 09:16:48.653673+00
c63947cf-bef4-4246-8750-f819f006341a	053e8dfd-cfb9-470d-995c-be55481732e0	requested	Booking created	2026-09-03 10:36:53.46323+00
47e6b2a8-1c4f-4f0a-851b-d35e45d491e4	053e8dfd-cfb9-470d-995c-be55481732e0	accepted	Technician assigned	2026-09-03 10:36:53.470291+00
0257bd96-1414-4373-a193-6e9c86f13a61	50ed0da7-a6ef-43ce-8f40-a1f79c284c22	on_the_way	Technician is on the way	2026-09-03 11:47:00.361824+00
03847a26-7745-43b9-a4a2-1f99cbebd4e2	c2e3fd6f-14b7-4147-87ff-a7f78d92592e	arrived	Technician has arrived	2026-09-03 11:47:12.485914+00
4fe860ec-eb63-4dc2-84fe-07b8050bfa05	8d322e61-9b4f-43cb-a8c9-f70d0deb9f8a	requested	Booking created	2026-09-04 02:33:34.973061+00
06cd6e6a-a966-46b7-a57b-5a0a75bec38d	8d322e61-9b4f-43cb-a8c9-f70d0deb9f8a	accepted	Technician assigned	2026-09-04 02:33:34.980584+00
9725d311-5a1b-4a18-adb1-b14fb9f2bbbf	c0caeee6-61ff-4109-991d-dc8705ea41d3	requested	Booking created	2026-09-04 02:35:20.955243+00
9a75ed82-aa62-4381-b8d5-0e0cdf97d99a	c0caeee6-61ff-4109-991d-dc8705ea41d3	accepted	Technician assigned	2026-09-04 02:35:20.95869+00
fdfe369e-9e20-4198-8e85-58f19a2bb90b	9a29e88d-004c-42d5-84b1-e48bb8c9dd06	requested	Booking created	2026-09-04 02:37:11.444335+00
563324e5-6b83-43f2-b734-ecec4a05f0f9	9a29e88d-004c-42d5-84b1-e48bb8c9dd06	accepted	Technician assigned	2026-09-04 02:37:11.448315+00
106f830d-e340-420f-92d6-685d26c6665e	c0caeee6-61ff-4109-991d-dc8705ea41d3	on_the_way	Technician is on the way	2026-09-04 02:37:44.895338+00
bb9ebf90-3a11-4b6c-a462-9a7fd169d149	c0caeee6-61ff-4109-991d-dc8705ea41d3	arrived	Technician has arrived	2026-09-04 02:37:56.244894+00
7a2fee11-9576-4db9-bcd9-f91026c0dac4	c0caeee6-61ff-4109-991d-dc8705ea41d3	inspecting	OTP verified, service started	2026-09-04 02:38:06.281589+00
6dbd03c3-a8b7-4b7e-baa0-0bad3140c3ab	9a29e88d-004c-42d5-84b1-e48bb8c9dd06	on_the_way	Technician is on the way	2026-09-04 03:02:16.112484+00
3a30f197-83cc-48eb-8a54-4d7cadfb861b	9a29e88d-004c-42d5-84b1-e48bb8c9dd06	arrived	Technician has arrived	2026-09-04 03:02:17.27015+00
0fea2d81-c806-487d-a1cf-e235cd09a556	ffb0bbac-d969-49c0-b9f4-51c9ae747776	requested	Booking created	2026-09-04 03:13:25.994575+00
34bcb1d5-ac8e-4984-be17-1a90584ea78f	ffb0bbac-d969-49c0-b9f4-51c9ae747776	accepted	Technician assigned	2026-09-04 03:13:26.001063+00
612d62d4-54a2-4014-aeb1-b93a317ecc00	ffb0bbac-d969-49c0-b9f4-51c9ae747776	on_the_way	Technician is on the way	2026-09-04 03:13:43.484209+00
b4bbf992-c35b-42ee-81f9-be2c96ddb3c0	ffb0bbac-d969-49c0-b9f4-51c9ae747776	arrived	Technician has arrived	2026-09-04 03:13:44.871052+00
9a61588b-2ec7-4763-bda0-38e0b934f236	ffb0bbac-d969-49c0-b9f4-51c9ae747776	inspecting	OTP verified, service started	2026-09-04 03:13:52.511625+00
39b1812e-f193-4fef-a07e-1bc71944537f	9aadbad3-538f-4771-9f4c-23fc70689baa	requested	Booking created	2026-09-04 04:00:47.962944+00
ecdf98fe-c167-44e7-92f9-ceb54e715464	9aadbad3-538f-4771-9f4c-23fc70689baa	accepted	Technician assigned	2026-09-04 04:00:47.969064+00
ecbb9f31-0eb9-48c2-9d4b-489b8ee94c89	9aadbad3-538f-4771-9f4c-23fc70689baa	on_the_way	Technician is on the way	2026-09-04 04:00:57.340681+00
d4295839-428a-49b0-b288-91f5294abeb8	9aadbad3-538f-4771-9f4c-23fc70689baa	arrived	Technician has arrived	2026-09-04 04:01:06.348287+00
a02d799c-6255-4f36-9279-5271bfa052b1	9aadbad3-538f-4771-9f4c-23fc70689baa	inspecting	OTP verified, service started	2026-09-04 04:01:14.19146+00
504c03a5-ceb0-44d2-a315-46a390e54e04	9aadbad3-538f-4771-9f4c-23fc70689baa	completed	Job completed	2026-09-04 04:09:19.482759+00
a3740766-4f5d-411d-b580-25250a66bd76	030ece2b-efa3-4d52-8777-f6f4624825e2	requested	Booking created	2026-09-04 04:09:25.304683+00
61661fe4-6df3-48b9-8ffc-2f4f44ef0da7	030ece2b-efa3-4d52-8777-f6f4624825e2	accepted	Technician assigned	2026-09-04 04:09:25.492276+00
1699db80-80af-44ea-8f7e-f13373acc4d5	030ece2b-efa3-4d52-8777-f6f4624825e2	on_the_way	Technician is on the way	2026-09-04 04:09:31.230302+00
23584d9c-cd58-446e-85a0-b6f34507eefa	030ece2b-efa3-4d52-8777-f6f4624825e2	arrived	Technician has arrived	2026-09-04 04:09:33.003129+00
15e62954-ccda-4dc7-911a-d176f2438d91	030ece2b-efa3-4d52-8777-f6f4624825e2	inspecting	OTP verified, service started	2026-09-04 04:09:40.154141+00
5e0e8374-a333-4a10-843a-634d9ad23b69	b6386401-faf3-4bc9-b3fa-01981e0c3c35	requested	Booking created	2026-09-04 04:44:16.349083+00
7c33709d-2d7f-4658-9678-82bc5350acf4	b6386401-faf3-4bc9-b3fa-01981e0c3c35	accepted	Technician assigned	2026-09-04 04:44:16.355222+00
e5235eb0-a044-4d6d-98b8-f1030518fc63	b6386401-faf3-4bc9-b3fa-01981e0c3c35	on_the_way	Technician is on the way	2026-09-04 04:44:35.753719+00
504eb474-8d00-4d79-aa08-18d7c2a7336c	b6386401-faf3-4bc9-b3fa-01981e0c3c35	arrived	Technician has arrived	2026-09-04 04:44:40.384465+00
589ad3dc-b20f-4f06-a88b-1d635603df8f	b6386401-faf3-4bc9-b3fa-01981e0c3c35	inspecting	OTP verified, service started	2026-09-04 04:44:49.511918+00
b820eef2-ed69-4015-bc7a-f5988dadee94	b6386401-faf3-4bc9-b3fa-01981e0c3c35	completed	Job completed	2026-09-04 04:45:11.164111+00
82a3f515-aea3-4f68-8f2c-28a13ebfa560	8031861e-f08c-4431-8c05-b8fa2ca57f40	requested	Booking created	2026-09-04 05:31:05.649458+00
3a2e941e-b8b1-4504-b80f-c13ecbab4cf9	8031861e-f08c-4431-8c05-b8fa2ca57f40	accepted	Technician assigned	2026-09-04 05:31:05.661183+00
395aea68-0347-497b-98b8-5ae6c2996e0b	86bea55f-a33f-4450-9cf6-23534d9976e5	cancelled	nsushsuen	2026-09-04 05:31:48.174748+00
171b9157-e9ef-4e77-8445-75617436bb76	e7cfec2d-65be-4642-9512-30a6fde5df38	requested	Booking created	2026-09-04 05:52:14.716666+00
7912ea66-ffd5-4a40-9e2f-21040ce66308	e7cfec2d-65be-4642-9512-30a6fde5df38	accepted	Technician assigned	2026-09-04 05:52:14.727462+00
e3d70b64-8a25-48df-aca8-de0070710730	e7cfec2d-65be-4642-9512-30a6fde5df38	on_the_way	Technician is on the way	2026-09-04 05:53:10.87618+00
1dfe3ad9-e6ff-4064-bc3a-fe12a9ba8823	e7cfec2d-65be-4642-9512-30a6fde5df38	arrived	Technician has arrived	2026-09-04 05:53:14.805235+00
0a2c62e9-db89-4d90-a5ee-9f73cec69017	e7cfec2d-65be-4642-9512-30a6fde5df38	inspecting	OTP verified, service started	2026-09-04 05:53:20.926612+00
7049bdfe-f5fb-4897-8cc4-09f28aa2f82a	e7cfec2d-65be-4642-9512-30a6fde5df38	completed	Job completed	2026-09-04 05:53:26.771883+00
c045311b-e923-4d50-9f2c-7e53e01b9359	1ac4424a-57da-4946-adf8-3260b1dcfe3c	requested	Booking created	2026-09-04 07:12:42.766546+00
ef9e4336-2d32-4268-a2bd-00f2c95565e8	1ac4424a-57da-4946-adf8-3260b1dcfe3c	accepted	Technician assigned	2026-09-04 07:12:42.771852+00
97cd6801-b9d6-4b56-a992-b622a7e31148	1ac4424a-57da-4946-adf8-3260b1dcfe3c	on_the_way	Technician is on the way	2026-09-04 07:13:20.863636+00
a719b533-4f00-4628-b869-d5936fdbfd87	1ac4424a-57da-4946-adf8-3260b1dcfe3c	arrived	Technician has arrived	2026-09-04 07:13:22.03934+00
682940e3-adc3-486e-bede-e9775cdd2ecd	1ac4424a-57da-4946-adf8-3260b1dcfe3c	inspecting	OTP verified, service started	2026-09-04 07:13:28.496972+00
3fad3c70-b7db-450e-9340-4c7bee56b4d3	1ac4424a-57da-4946-adf8-3260b1dcfe3c	completed	Job completed	2026-09-04 07:13:35.443385+00
185629ec-9cf8-4ea3-8ee7-0bd43ab8272f	4a8fb8f6-8129-4b01-99ff-e2664b45214d	requested	Booking created	2026-09-04 08:55:48.446023+00
71beff13-3306-46a0-aabd-933f696124e8	4a8fb8f6-8129-4b01-99ff-e2664b45214d	accepted	Technician assigned	2026-09-04 08:55:48.451898+00
f6196767-7bc9-4bfb-a71d-aaec3f5c9986	4a8fb8f6-8129-4b01-99ff-e2664b45214d	on_the_way	Technician is on the way	2026-09-04 08:56:07.819396+00
2dd2925f-05f3-4451-b705-3affa9258013	4a8fb8f6-8129-4b01-99ff-e2664b45214d	arrived	Technician has arrived	2026-09-04 08:56:10.291462+00
962709bf-8e5a-4b91-bc43-065dad91a202	4a8fb8f6-8129-4b01-99ff-e2664b45214d	inspecting	OTP verified, service started	2026-09-04 08:56:18.045303+00
c606c074-ec93-4b14-b9b4-57c6982b16da	4a8fb8f6-8129-4b01-99ff-e2664b45214d	completed	Job completed	2026-09-04 08:56:38.472682+00
e70abfab-1386-44e4-b6f3-a736b81c0bdd	9a8facc2-f8c9-4721-aebb-45615a91aa2d	requested	Booking created	2026-09-04 09:03:53.754163+00
cab7ca29-773d-4e6d-a9b1-5bfb60eaf14b	9a8facc2-f8c9-4721-aebb-45615a91aa2d	accepted	Technician assigned	2026-09-04 09:03:53.759768+00
\.


--
-- Data for Name: bookings; Type: TABLE DATA; Schema: public; Owner: homefix_db_wuc1_user
--

COPY public.bookings (id, customer_id, technician_id, category_id, address_id, status, problem_description, scheduled_at, estimated_price, final_price, created_at, updated_at, notes, images, payment_status, service_code, otp_code, otp_verified_at, warranty_enabled, warranty_days, warranty_expires_at, is_warranty_claim, warranty_claim_of, visit_fee_amount, visit_fee_status, visit_fee_charged) FROM stdin;
86bea55f-a33f-4450-9cf6-23534d9976e5	aebfbed2-7205-437b-9045-65d1b0240e6a	e9977c7e-f0a5-4284-95a6-f535a31b0c9f	1951b819-8776-4183-80ab-ea271aac9e85	1dec1ea7-7e4a-4b07-97cd-844c5e86015d	cancelled		\N	299.00	\N	2026-09-01 06:06:44.535026+00	2026-09-04 05:31:48.174748+00	\N	\N	pending	SRV-001034	\N	\N	f	\N	\N	f	\N	\N	\N	f
af6067b5-d9ef-4ffe-9a18-bbe5f2589f32	aebfbed2-7205-437b-9045-65d1b0240e6a	e9977c7e-f0a5-4284-95a6-f535a31b0c9f	1951b819-8776-4183-80ab-ea271aac9e85	1dec1ea7-7e4a-4b07-97cd-844c5e86015d	accepted		\N	299.00	\N	2026-08-30 02:47:59.918917+00	2026-08-30 02:47:59.922221+00	\N	\N	pending	SRV-001011	\N	\N	f	\N	\N	f	\N	\N	\N	f
e70405d7-2471-42eb-b587-8f8242a67a01	dc3f702c-b385-4c27-9057-0325c0b5013d	ff7fa15e-6118-4cc5-9939-5d1e34799898	67870415-027c-4371-814b-3d80c0f67b7f	cf6dcd0c-148b-4463-a20a-dfb2d1818b33	completed	celling problem	2026-08-29 07:30:00+00	299.00	299.00	2026-08-29 06:47:01.040704+00	2026-08-29 06:47:45.217905+00	\N	\N	pending	SRV-001000	\N	\N	f	\N	\N	f	\N	\N	\N	f
f6d1c69c-8a4a-4a40-af39-4217a4c404b8	aebfbed2-7205-437b-9045-65d1b0240e6a	56e6825f-1d28-4030-9831-8179f43ed3a8	763c06cc-2221-40d6-93db-9557a7c47aec	1dec1ea7-7e4a-4b07-97cd-844c5e86015d	arrived		\N	199.00	\N	2026-08-31 06:22:16.917007+00	2026-08-31 06:22:22.240322+00	\N	\N	pending	SRV-001023	0810	\N	f	\N	\N	f	\N	\N	\N	f
ad934dd3-d075-4515-8acf-92c82c2b0e6d	aebfbed2-7205-437b-9045-65d1b0240e6a	e9977c7e-f0a5-4284-95a6-f535a31b0c9f	1951b819-8776-4183-80ab-ea271aac9e85	30dec4a6-9c9f-482f-8e2b-37e6853404dc	cancelled		\N	299.00	\N	2026-09-02 04:47:07.362217+00	2026-09-02 04:53:05.627767+00	\N	\N	pending	SRV-001043	\N	\N	f	\N	\N	f	\N	\N	\N	f
5d859f37-e87a-4369-8d52-1c94d9f837d5	dc3f702c-b385-4c27-9057-0325c0b5013d	ff7fa15e-6118-4cc5-9939-5d1e34799898	67870415-027c-4371-814b-3d80c0f67b7f	cf6dcd0c-148b-4463-a20a-dfb2d1818b33	completed		2026-08-29 07:05:00+00	299.00	299.00	2026-08-29 07:05:18.250454+00	2026-08-29 07:13:48.91953+00	\N	\N	pending	SRV-001001	\N	\N	f	\N	\N	f	\N	\N	\N	f
98b8c4e5-0939-44ee-a66e-8c069d3f110a	aebfbed2-7205-437b-9045-65d1b0240e6a	56e6825f-1d28-4030-9831-8179f43ed3a8	763c06cc-2221-40d6-93db-9557a7c47aec	1dec1ea7-7e4a-4b07-97cd-844c5e86015d	arrived		\N	199.00	\N	2026-08-31 06:26:59.096186+00	2026-08-31 06:27:06.731091+00	\N	\N	pending	SRV-001024	1629	\N	f	\N	\N	f	\N	\N	\N	f
ee0f264e-3679-4ff8-8c85-0e75b8793e14	aebfbed2-7205-437b-9045-65d1b0240e6a	e9977c7e-f0a5-4284-95a6-f535a31b0c9f	1951b819-8776-4183-80ab-ea271aac9e85	1dec1ea7-7e4a-4b07-97cd-844c5e86015d	accepted		2026-08-31 03:30:00+00	299.00	\N	2026-08-30 18:09:19.287133+00	2026-08-30 18:09:19.291779+00	\N	\N	pending	SRV-001012	\N	\N	f	\N	\N	f	\N	\N	\N	f
6159f686-4eca-4829-8984-8d748016d126	aebfbed2-7205-437b-9045-65d1b0240e6a	e9977c7e-f0a5-4284-95a6-f535a31b0c9f	1951b819-8776-4183-80ab-ea271aac9e85	1dec1ea7-7e4a-4b07-97cd-844c5e86015d	completed	ceiling issue	2026-08-29 07:21:00+00	299.00	399.00	2026-08-29 07:21:49.272738+00	2026-08-29 07:24:26.449555+00	\N	\N	paid	SRV-001002	\N	\N	f	\N	\N	f	\N	\N	\N	f
cf08d139-b61e-40ba-b4ad-26c92233673a	4f3d12f3-d8a6-4c97-8016-2d44b252426f	ff7fa15e-6118-4cc5-9939-5d1e34799898	67870415-027c-4371-814b-3d80c0f67b7f	baadacd1-e570-4cb5-9cbf-0b75198d43f2	accepted	Want Ac service	2026-09-01 06:30:00+00	299.00	\N	2026-08-29 07:52:30.987566+00	2026-08-29 07:52:30.993224+00	\N	\N	pending	SRV-001003	\N	\N	f	\N	\N	f	\N	\N	\N	f
f4149c23-8927-400a-889e-5e8a466e38df	5978c7ed-c201-40f9-ac16-08fcb5d81431	ff7fa15e-6118-4cc5-9939-5d1e34799898	67870415-027c-4371-814b-3d80c0f67b7f	e3bdc6f5-88d2-4174-8f39-f92892457e59	accepted	jwiejsbs	2026-08-29 12:04:00+00	299.00	\N	2026-08-29 08:05:33.868959+00	2026-08-29 08:05:33.872882+00	\N	\N	pending	SRV-001004	\N	\N	f	\N	\N	f	\N	\N	\N	f
9db1257c-e883-4d18-b922-5e88d366e304	5978c7ed-c201-40f9-ac16-08fcb5d81431	ff7fa15e-6118-4cc5-9939-5d1e34799898	67870415-027c-4371-814b-3d80c0f67b7f	e3bdc6f5-88d2-4174-8f39-f92892457e59	accepted	ac is not working\nmy ac is not working\n\njwjen	2026-08-29 10:34:00+00	299.00	\N	2026-08-29 08:34:40.522194+00	2026-08-29 08:34:40.528061+00	\N	\N	pending	SRV-001005	\N	\N	f	\N	\N	f	\N	\N	\N	f
61e186b5-63fa-457a-a56c-3789f77e8e79	aebfbed2-7205-437b-9045-65d1b0240e6a	56e6825f-1d28-4030-9831-8179f43ed3a8	763c06cc-2221-40d6-93db-9557a7c47aec	1dec1ea7-7e4a-4b07-97cd-844c5e86015d	arrived		\N	199.00	\N	2026-08-31 06:29:31.044308+00	2026-08-31 06:29:40.283388+00	\N	\N	pending	SRV-001025	1884	\N	f	\N	\N	f	\N	\N	\N	f
26823039-9062-4987-97a8-06b71e66f580	ef023969-5324-493a-ad92-0ce013f4a1ca	ff7fa15e-6118-4cc5-9939-5d1e34799898	67870415-027c-4371-814b-3d80c0f67b7f	15c8fcef-a955-4e05-8fa4-c15aeee3ff56	accepted	my ac falls back to room\nwosos odo\n Stop over here.\n माझने इसी खराब जाने में ले ठीक को मिलोगी	2026-08-29 08:48:00+00	299.00	\N	2026-08-29 08:48:20.579049+00	2026-08-29 08:48:20.582446+00	\N	\N	pending	SRV-001007	\N	\N	f	\N	\N	f	\N	\N	\N	f
b5812643-16d6-4b05-b6d8-e8f14a9d8b29	4f3d12f3-d8a6-4c97-8016-2d44b252426f	56e6825f-1d28-4030-9831-8179f43ed3a8	763c06cc-2221-40d6-93db-9557a7c47aec	baadacd1-e570-4cb5-9cbf-0b75198d43f2	completed	issue\nissue\n\njaja	2026-08-31 06:30:00+00	199.00	199.00	2026-08-29 08:41:53.240637+00	2026-08-29 09:05:18.326493+00	\N	\N	pending	SRV-001006	\N	\N	f	\N	\N	f	\N	\N	\N	f
38839d69-9794-4989-95a0-2fb767af3575	aebfbed2-7205-437b-9045-65d1b0240e6a	56e6825f-1d28-4030-9831-8179f43ed3a8	763c06cc-2221-40d6-93db-9557a7c47aec	1dec1ea7-7e4a-4b07-97cd-844c5e86015d	arrived		\N	199.00	\N	2026-08-31 06:42:33.43292+00	2026-08-31 06:42:39.096786+00	\N	\N	pending	SRV-001026	4996	\N	f	\N	\N	f	\N	\N	\N	f
08c5ea8e-e260-4e2d-b604-be16d8092334	aebfbed2-7205-437b-9045-65d1b0240e6a	e9977c7e-f0a5-4284-95a6-f535a31b0c9f	1951b819-8776-4183-80ab-ea271aac9e85	1dec1ea7-7e4a-4b07-97cd-844c5e86015d	accepted		\N	299.00	\N	2026-08-29 11:00:18.274136+00	2026-08-29 11:00:18.282453+00	\N	\N	pending	SRV-001008	\N	\N	f	\N	\N	f	\N	\N	\N	f
dad82ade-9ea9-4256-9005-988faba26cba	aebfbed2-7205-437b-9045-65d1b0240e6a	56e6825f-1d28-4030-9831-8179f43ed3a8	763c06cc-2221-40d6-93db-9557a7c47aec	1dec1ea7-7e4a-4b07-97cd-844c5e86015d	on_the_way		2026-08-30 05:30:00+00	199.00	\N	2026-08-30 01:09:29.091393+00	2026-08-30 02:27:46.064941+00	\N	\N	pending	SRV-001009	\N	\N	f	\N	\N	f	\N	\N	\N	f
aca4efb5-c668-448f-8330-f4b71ae2238c	aebfbed2-7205-437b-9045-65d1b0240e6a	e9977c7e-f0a5-4284-95a6-f535a31b0c9f	1951b819-8776-4183-80ab-ea271aac9e85	1dec1ea7-7e4a-4b07-97cd-844c5e86015d	accepted		2026-08-30 05:30:00+00	299.00	\N	2026-08-30 02:47:22.495281+00	2026-08-30 02:47:22.49939+00	\N	\N	pending	SRV-001010	\N	\N	f	\N	\N	f	\N	\N	\N	f
341036e8-d595-4979-b2f5-346bc5f02962	aebfbed2-7205-437b-9045-65d1b0240e6a	56e6825f-1d28-4030-9831-8179f43ed3a8	763c06cc-2221-40d6-93db-9557a7c47aec	1dec1ea7-7e4a-4b07-97cd-844c5e86015d	inspecting		\N	199.00	\N	2026-08-31 06:52:54.177571+00	2026-08-31 06:53:08.822201+00	\N	\N	pending	SRV-001027	2407	2026-08-31 06:53:08.820464	f	\N	\N	f	\N	\N	\N	f
fd7da0bc-0c12-4140-b6fa-b74bbd7e714c	aebfbed2-7205-437b-9045-65d1b0240e6a	56e6825f-1d28-4030-9831-8179f43ed3a8	763c06cc-2221-40d6-93db-9557a7c47aec	1dec1ea7-7e4a-4b07-97cd-844c5e86015d	cancelled		\N	199.00	\N	2026-08-30 18:18:33.156847+00	2026-08-30 18:19:12.223687+00	\N	\N	pending	SRV-001014	\N	\N	f	\N	\N	f	\N	\N	\N	f
68bc8edb-976c-4030-bc76-89486f0ea45c	aebfbed2-7205-437b-9045-65d1b0240e6a	56e6825f-1d28-4030-9831-8179f43ed3a8	763c06cc-2221-40d6-93db-9557a7c47aec	1dec1ea7-7e4a-4b07-97cd-844c5e86015d	on_the_way		2026-08-30 13:17:00+00	199.00	\N	2026-08-30 18:17:25.35506+00	2026-08-30 18:19:26.483095+00	\N	\N	pending	SRV-001013	\N	\N	f	\N	\N	f	\N	\N	\N	f
56170d9e-66d0-4cf4-a346-eb76cec2856b	aebfbed2-7205-437b-9045-65d1b0240e6a	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	1dec1ea7-7e4a-4b07-97cd-844c5e86015d	inspecting		\N	179.00	\N	2026-08-31 09:05:25.499882+00	2026-08-31 09:05:41.620154+00	\N	\N	pending	SRV-001031	0073	2026-08-31 09:05:41.617392	f	\N	\N	f	\N	\N	\N	f
144a9b77-35dd-48ca-ac63-d4fa3c2b8d1a	aebfbed2-7205-437b-9045-65d1b0240e6a	56e6825f-1d28-4030-9831-8179f43ed3a8	763c06cc-2221-40d6-93db-9557a7c47aec	1dec1ea7-7e4a-4b07-97cd-844c5e86015d	on_the_way	gyhh gujn	\N	199.00	\N	2026-08-31 03:02:58.25162+00	2026-08-31 03:03:11.486036+00	\N	\N	pending	SRV-001015	\N	\N	f	\N	\N	f	\N	\N	\N	f
271820c9-e8ee-4424-abfc-ffb4ab065c02	aebfbed2-7205-437b-9045-65d1b0240e6a	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	1dec1ea7-7e4a-4b07-97cd-844c5e86015d	inspecting		2026-08-31 08:30:00+00	179.00	\N	2026-08-31 09:04:33.165134+00	2026-08-31 09:04:50.006634+00	\N	\N	pending	SRV-001030	8894	2026-08-31 09:04:50.004249	f	\N	\N	f	\N	\N	\N	f
a7a39d1e-27f4-4855-9a21-3132d0dbbddc	aebfbed2-7205-437b-9045-65d1b0240e6a	56e6825f-1d28-4030-9831-8179f43ed3a8	763c06cc-2221-40d6-93db-9557a7c47aec	1dec1ea7-7e4a-4b07-97cd-844c5e86015d	inspecting		\N	199.00	\N	2026-08-31 06:55:08.980474+00	2026-08-31 06:55:24.124056+00	\N	\N	pending	SRV-001028	1020	2026-08-31 06:55:24.122738	f	\N	\N	f	\N	\N	\N	f
9ecf2820-25fb-46c3-9429-8ba10e59398e	aebfbed2-7205-437b-9045-65d1b0240e6a	e9977c7e-f0a5-4284-95a6-f535a31b0c9f	1951b819-8776-4183-80ab-ea271aac9e85	1dec1ea7-7e4a-4b07-97cd-844c5e86015d	accepted		\N	299.00	\N	2026-08-31 05:08:00.403263+00	2026-08-31 05:08:00.409275+00	\N	\N	pending	SRV-001017	\N	\N	f	\N	\N	f	\N	\N	\N	f
74bbd88d-6558-400a-be33-5babcc7a841b	aebfbed2-7205-437b-9045-65d1b0240e6a	56e6825f-1d28-4030-9831-8179f43ed3a8	763c06cc-2221-40d6-93db-9557a7c47aec	1dec1ea7-7e4a-4b07-97cd-844c5e86015d	arrived		\N	199.00	\N	2026-08-31 04:57:25.893447+00	2026-08-31 05:09:20.63317+00	\N	\N	pending	SRV-001016	\N	\N	f	\N	\N	f	\N	\N	\N	f
97804867-d6df-4dcb-9ab4-458d025d57b0	aebfbed2-7205-437b-9045-65d1b0240e6a	56e6825f-1d28-4030-9831-8179f43ed3a8	763c06cc-2221-40d6-93db-9557a7c47aec	1dec1ea7-7e4a-4b07-97cd-844c5e86015d	on_the_way	d6ufi	\N	199.00	\N	2026-08-31 05:30:56.967442+00	2026-08-31 05:31:17.999147+00	\N	\N	pending	SRV-001018	\N	\N	f	\N	\N	f	\N	\N	\N	f
ebfcf350-dcd8-498d-b0c7-bab5ea2b6408	aebfbed2-7205-437b-9045-65d1b0240e6a	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	1dec1ea7-7e4a-4b07-97cd-844c5e86015d	inspecting		\N	179.00	\N	2026-08-31 06:59:27.618004+00	2026-08-31 06:59:42.584739+00	\N	\N	pending	SRV-001029	5630	2026-08-31 06:59:42.582996	f	\N	\N	f	\N	\N	\N	f
57538146-3db7-4baa-b383-090b36ab505e	aebfbed2-7205-437b-9045-65d1b0240e6a	56e6825f-1d28-4030-9831-8179f43ed3a8	763c06cc-2221-40d6-93db-9557a7c47aec	1dec1ea7-7e4a-4b07-97cd-844c5e86015d	arrived		\N	199.00	\N	2026-08-31 05:32:27.027596+00	2026-08-31 05:32:41.142125+00	\N	\N	pending	SRV-001019	\N	\N	f	\N	\N	f	\N	\N	\N	f
bdd5c7c5-4dff-49ba-85ab-25045ee16276	aebfbed2-7205-437b-9045-65d1b0240e6a	56e6825f-1d28-4030-9831-8179f43ed3a8	763c06cc-2221-40d6-93db-9557a7c47aec	1dec1ea7-7e4a-4b07-97cd-844c5e86015d	arrived		\N	199.00	\N	2026-08-31 06:07:21.062253+00	2026-08-31 06:07:29.095142+00	\N	\N	pending	SRV-001022	0363	\N	f	\N	\N	f	\N	\N	\N	f
0a5791e9-c5bc-42b4-96d0-530df2bc92b1	aebfbed2-7205-437b-9045-65d1b0240e6a	56e6825f-1d28-4030-9831-8179f43ed3a8	763c06cc-2221-40d6-93db-9557a7c47aec	1dec1ea7-7e4a-4b07-97cd-844c5e86015d	arrived		\N	199.00	\N	2026-08-31 05:39:14.673761+00	2026-08-31 05:51:12.57024+00	\N	\N	pending	SRV-001020	\N	\N	f	\N	\N	f	\N	\N	\N	f
8bf61946-c99c-4096-a1f4-4f7184b454eb	aebfbed2-7205-437b-9045-65d1b0240e6a	56e6825f-1d28-4030-9831-8179f43ed3a8	763c06cc-2221-40d6-93db-9557a7c47aec	1dec1ea7-7e4a-4b07-97cd-844c5e86015d	arrived		\N	199.00	\N	2026-08-31 05:51:41.420522+00	2026-08-31 05:51:52.292238+00	\N	\N	pending	SRV-001021	0728	\N	f	\N	\N	f	\N	\N	\N	f
9640544d-5c9f-4d3f-a1a4-ec751bd6e1bd	aebfbed2-7205-437b-9045-65d1b0240e6a	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	1dec1ea7-7e4a-4b07-97cd-844c5e86015d	inspecting		\N	179.00	\N	2026-08-31 17:26:30.050888+00	2026-08-31 17:26:49.091906+00	[JobBrief]{"startedWhen":"Today","isContinuous":true,"previousRepair":true,"isEmergency":false,"aiDiagnosis":"{\\n  \\"possible_fault\\": \\"Unspecified issue\\",\\n  \\"causes\\": [],\\n  \\"follow_up_questions\\": [\\n    \\"Can you describe the problem you are experiencing in detail?\\",\\n    \\"Which part of the home (kitchen, bathroom, living area, etc.) is affected?\\",\\n    \\"Is the issue related to plumbing, electrical, HVAC, appliances, or something else?\\",\\n    \\"When did the problem start, and does it happen intermittently or continuously?\\"\\n  ],\\n  \\"confidence_score\\": 30,\\n  \\"estimated_cost_min\\": 500,\\n  \\"estimated_cost_max\\": 1500,\\n  \\"estimated_time_minutes\\": 30,\\n  \\"can_solve_remotely\\": false,\\n  \\"recommendation\\": \\"onsite\\"\\n}"}	\N	pending	SRV-001032	1184	2026-08-31 17:26:49.084176	f	\N	\N	f	\N	\N	\N	f
1f64b5e0-817e-435b-b7f3-c2d8b1df47e7	aebfbed2-7205-437b-9045-65d1b0240e6a	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	1dec1ea7-7e4a-4b07-97cd-844c5e86015d	inspecting		\N	179.00	\N	2026-09-01 03:09:36.001133+00	2026-09-01 03:09:49.099884+00	\N	\N	pending	SRV-001033	9239	2026-09-01 03:09:49.098287	f	\N	\N	f	\N	\N	\N	f
94f58d5b-b308-4537-9d2b-6c444a60e310	3be2026d-ea02-43f3-bc41-e0b3e9bb133c	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	ff6bd475-bd7d-4b77-b120-8a9f6d5d479f	inspecting		\N	179.00	\N	2026-09-01 06:23:19.076725+00	2026-09-01 06:23:45.328258+00	\N	\N	pending	SRV-001035	6040	2026-09-01 06:23:45.324661	f	\N	\N	f	\N	\N	\N	f
dd974c8f-062c-47e0-9079-945a264c324e	aebfbed2-7205-437b-9045-65d1b0240e6a	ff7fa15e-6118-4cc5-9939-5d1e34799898	67870415-027c-4371-814b-3d80c0f67b7f	1dec1ea7-7e4a-4b07-97cd-844c5e86015d	accepted	ceiling issue\nceiling issue	\N	299.00	\N	2026-09-01 07:00:59.225828+00	2026-09-01 07:00:59.232164+00	[JobBrief]{"startedWhen":"Today","isContinuous":true,"previousRepair":false,"isEmergency":false,"aiDiagnosis":"{\\n  \\"possible_fault\\": \\"Potential ceiling damage (e.g., water leak, cracking, sagging)\\",\\n  \\"causes\\": [\\n    \\"Water leakage from roof or plumbing\\",\\n    \\"Structural settlement or framing issues\\",\\n    \\"Improper plastering or finishing\\"\\n  ],\\n  \\"follow_up_questions\\": [\\n    \\"Are there visible cracks, stains, or sagging in the ceiling?\\",\\n    \\"Did the problem start after any recent water usage, roof work, or rain?\\",\\n    \\"Is there a ceiling fan or light fixture attached to the affected area?\\",\\n    \\"How long has the issue been present and is it getting worse?\\"\\n  ],\\n  \\"confidence_score\\": 30,\\n  \\"estimated_cost_min\\": 1500,\\n  \\"estimated_cost_max\\": 5000,\\n  \\"estimated_time_minutes\\": 30,\\n  \\"can_solve_remotely\\": false,\\n  \\"recommendation\\": \\"onsite\\"\\n}"}	\N	pending	SRV-001036	\N	\N	f	\N	\N	f	\N	\N	\N	f
b85f589c-990b-4905-89ab-0af5524b6001	aebfbed2-7205-437b-9045-65d1b0240e6a	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	30dec4a6-9c9f-482f-8e2b-37e6853404dc	accepted		2026-09-03 03:30:00+00	179.00	\N	2026-09-03 09:16:48.643496+00	2026-09-03 09:16:48.653673+00	[JobBrief]{"categoryAnswers":{"Where is the problem?":"Kitchen","What's the issue?":"Leakage"}}	\N	pending	SRV-001073	\N	\N	f	\N	\N	f	\N	\N	\N	f
b16efaa0-4d95-4044-b794-62e407559ac6	aebfbed2-7205-437b-9045-65d1b0240e6a	e9977c7e-f0a5-4284-95a6-f535a31b0c9f	1951b819-8776-4183-80ab-ea271aac9e85	1dec1ea7-7e4a-4b07-97cd-844c5e86015d	cancelled		\N	299.00	\N	2026-09-02 04:47:31.819604+00	2026-09-02 04:49:39.092367+00	\N	\N	pending	SRV-001044	\N	\N	f	\N	\N	f	\N	\N	\N	f
3e55eab3-e739-46dd-94aa-48293f7b4663	aebfbed2-7205-437b-9045-65d1b0240e6a	e9977c7e-f0a5-4284-95a6-f535a31b0c9f	1951b819-8776-4183-80ab-ea271aac9e85	30dec4a6-9c9f-482f-8e2b-37e6853404dc	accepted		\N	299.00	\N	2026-09-02 07:01:29.904764+00	2026-09-02 07:01:29.911059+00	\N	\N	pending	SRV-001046	\N	\N	f	\N	\N	f	\N	\N	\N	f
c2e3fd6f-14b7-4147-87ff-a7f78d92592e	3be2026d-ea02-43f3-bc41-e0b3e9bb133c	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	ff6bd475-bd7d-4b77-b120-8a9f6d5d479f	arrived	iegxirgxirgir	2026-09-02 18:30:00+00	299.00	\N	2026-09-03 03:17:40.594509+00	2026-09-03 11:47:12.4893+00	[JobBrief]{"hasVideo":true,"consultationNotes":"Video consultation completed with Pratiksha before this visit."}	\N	pending	SRV-001054	0234	\N	f	\N	\N	f	\N	99.00	pending	f
ed453b6d-8abd-4ece-b23d-4964ddc56002	aebfbed2-7205-437b-9045-65d1b0240e6a	56e6825f-1d28-4030-9831-8179f43ed3a8	763c06cc-2221-40d6-93db-9557a7c47aec	1dec1ea7-7e4a-4b07-97cd-844c5e86015d	accepted		\N	199.00	\N	2026-09-02 07:01:48.337454+00	2026-09-02 07:01:48.343555+00	\N	\N	pending	SRV-001047	\N	\N	f	\N	\N	f	\N	\N	\N	f
4a1cca6f-0c29-45a4-86fd-c6da18db7024	aebfbed2-7205-437b-9045-65d1b0240e6a	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	1dec1ea7-7e4a-4b07-97cd-844c5e86015d	accepted		\N	179.00	\N	2026-09-02 07:53:14.278451+00	2026-09-02 07:53:14.284582+00	\N	\N	pending	SRV-001049	\N	\N	f	\N	\N	f	\N	\N	\N	f
8d322e61-9b4f-43cb-a8c9-f70d0deb9f8a	9dd63068-5ba2-487e-ab79-aa0bb4f686f5	ff7fa15e-6118-4cc5-9939-5d1e34799898	67870415-027c-4371-814b-3d80c0f67b7f	80c85490-8d0b-4147-89be-3b734106ae3e	accepted		2026-09-11 05:30:00+00	299.00	\N	2026-09-04 02:33:34.973061+00	2026-09-04 02:33:34.980584+00	[JobBrief]{"categoryAnswers":{"What's the issue?":"Not cooling","AC type":"Window AC"}}	\N	pending	SRV-001075	\N	\N	f	\N	\N	f	\N	\N	\N	f
49c23089-e873-4e38-8ce0-52da9a4f2787	aebfbed2-7205-437b-9045-65d1b0240e6a	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	30dec4a6-9c9f-482f-8e2b-37e6853404dc	completed		\N	179.00	179.00	2026-09-03 03:36:07.229015+00	2026-09-03 04:04:56.556639+00	\N	\N	pending	SRV-001055	8262	2026-09-03 03:36:20.069174	f	\N	\N	f	\N	\N	\N	f
4e3bf9f3-2f68-4892-a9d5-444ae1e3f388	3be2026d-ea02-43f3-bc41-e0b3e9bb133c	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	ff6bd475-bd7d-4b77-b120-8a9f6d5d479f	inspecting		\N	179.00	\N	2026-09-03 03:13:01.483053+00	2026-09-03 03:13:15.027981+00	\N	\N	pending	SRV-001051	5608	2026-09-03 03:13:15.026368	f	\N	\N	f	\N	\N	\N	f
fb01b515-45a9-48ae-8126-9ff7044ebe64	3be2026d-ea02-43f3-bc41-e0b3e9bb133c	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	ff6bd475-bd7d-4b77-b120-8a9f6d5d479f	arrived		\N	179.00	\N	2026-09-03 03:15:00.704865+00	2026-09-03 03:15:09.006139+00	\N	\N	pending	SRV-001052	7047	\N	f	\N	\N	f	\N	\N	\N	f
9aadbad3-538f-4771-9f4c-23fc70689baa	aebfbed2-7205-437b-9045-65d1b0240e6a	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	30dec4a6-9c9f-482f-8e2b-37e6853404dc	completed		2026-09-04 03:30:00+00	179.00	179.00	2026-09-04 04:00:47.962944+00	2026-09-04 04:09:19.482759+00	[JobBrief]{"categoryAnswers":{"What's the issue?":"Leakage","Where is the problem?":"Kitchen"}}	\N	pending	SRV-001079	0892	2026-09-04 04:01:14.189342	f	\N	\N	f	\N	\N	\N	f
c0caeee6-61ff-4109-991d-dc8705ea41d3	9dd63068-5ba2-487e-ab79-aa0bb4f686f5	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	80c85490-8d0b-4147-89be-3b734106ae3e	inspecting		2026-09-05 02:35:00+00	179.00	\N	2026-09-04 02:35:20.955243+00	2026-09-04 02:38:06.281589+00	[JobBrief]{"hasVideo":true,"consultationNotes":"Video consultation completed with Pratiksha before this visit."}	\N	pending	SRV-001076	1753	2026-09-04 02:38:06.280038	f	\N	\N	f	\N	99.00	pending	f
9a29e88d-004c-42d5-84b1-e48bb8c9dd06	9dd63068-5ba2-487e-ab79-aa0bb4f686f5	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	80c85490-8d0b-4147-89be-3b734106ae3e	arrived	vehdubd	\N	258.00	\N	2026-09-04 02:37:11.444335+00	2026-09-04 03:02:17.273023+00		\N	pending	SRV-001077	2230	\N	f	\N	\N	f	\N	99.00	pending	f
2041b386-bc65-469a-b8e4-10bb153d8d69	aebfbed2-7205-437b-9045-65d1b0240e6a	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	30dec4a6-9c9f-482f-8e2b-37e6853404dc	accepted		\N	179.00	\N	2026-09-03 05:03:08.773456+00	2026-09-03 05:03:08.783499+00	\N	\N	pending	SRV-001057	\N	\N	f	\N	\N	f	\N	\N	\N	f
619e39f7-7322-43d9-9b7f-199a6e826c67	aebfbed2-7205-437b-9045-65d1b0240e6a	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	30dec4a6-9c9f-482f-8e2b-37e6853404dc	accepted		\N	179.00	\N	2026-09-03 05:32:52.965267+00	2026-09-03 05:32:52.971891+00	\N	\N	pending	SRV-001059	\N	\N	f	\N	\N	f	\N	\N	\N	f
6cfc011e-04f5-422f-8f42-e4e073364b39	aebfbed2-7205-437b-9045-65d1b0240e6a	ff7fa15e-6118-4cc5-9939-5d1e34799898	67870415-027c-4371-814b-3d80c0f67b7f	1dec1ea7-7e4a-4b07-97cd-844c5e86015d	accepted		\N	299.00	\N	2026-09-03 05:33:13.001467+00	2026-09-03 05:33:13.004958+00	\N	\N	pending	SRV-001060	\N	\N	f	\N	\N	f	\N	\N	\N	f
7fa3e04d-2fba-467f-961e-55610b39ac8c	3be2026d-ea02-43f3-bc41-e0b3e9bb133c	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	ff6bd475-bd7d-4b77-b120-8a9f6d5d479f	accepted		\N	179.00	\N	2026-09-03 05:55:09.092678+00	2026-09-03 05:55:09.097949+00	\N	\N	pending	SRV-001062	\N	\N	f	\N	\N	f	\N	\N	\N	f
82b00ea2-a795-4bde-aa78-8cd9956f14bc	3be2026d-ea02-43f3-bc41-e0b3e9bb133c	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	ff6bd475-bd7d-4b77-b120-8a9f6d5d479f	arrived		\N	179.00	\N	2026-09-03 05:55:37.129533+00	2026-09-03 06:29:30.368252+00	\N	\N	pending	SRV-001063	7452	\N	f	\N	\N	f	\N	\N	\N	f
b6386401-faf3-4bc9-b3fa-01981e0c3c35	aebfbed2-7205-437b-9045-65d1b0240e6a	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	30dec4a6-9c9f-482f-8e2b-37e6853404dc	completed		2026-09-05 05:30:00+00	179.00	179.00	2026-09-04 04:44:16.349083+00	2026-09-04 04:45:11.164111+00	[JobBrief]{"categoryAnswers":{"What's the issue?":"New fitting/installation","Where is the problem?":"Overhead tank"}}	\N	pending	SRV-001081	2157	2026-09-04 04:44:49.510127	t	7	2026-09-11 04:45:11.162474+00	f	\N	\N	\N	f
56aca21f-96e2-4382-a098-5fa364070cb5	3be2026d-ea02-43f3-bc41-e0b3e9bb133c	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	ff6bd475-bd7d-4b77-b120-8a9f6d5d479f	repair_in_progress		2026-09-03 03:30:00+00	179.00	\N	2026-09-03 07:18:14.677349+00	2026-09-03 07:18:30.095747+00	\N	\N	pending	SRV-001067	7383	2026-09-03 07:18:30.094182	f	\N	\N	f	\N	\N	\N	f
e7cfec2d-65be-4642-9512-30a6fde5df38	aebfbed2-7205-437b-9045-65d1b0240e6a	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	30dec4a6-9c9f-482f-8e2b-37e6853404dc	completed	Customer attached a video: https://homefix-b61f.onrender.com/uploads/67c6ca13-4242-40a3-a647-40b48d8849b5.mp4	2026-09-04 05:30:00+00	179.00	179.00	2026-09-04 05:52:14.716666+00	2026-09-04 05:53:26.771883+00	[JobBrief]{"categoryAnswers":{"What's the issue?":"Tap/valve repair","Where is the problem?":"Overhead tank"}}	{https://homefix-b61f.onrender.com/uploads/7aa40194-4da5-4fbb-a12c-7af6d1dc3b9a.png}	pending	SRV-001083	3541	2026-09-04 05:53:20.924971	t	7	2026-09-11 05:53:26.76977+00	f	\N	\N	\N	f
4a8fb8f6-8129-4b01-99ff-e2664b45214d	aebfbed2-7205-437b-9045-65d1b0240e6a	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	30dec4a6-9c9f-482f-8e2b-37e6853404dc	completed		2026-09-04 08:55:00+00	179.00	179.00	2026-09-04 08:55:48.446023+00	2026-09-04 08:56:38.472682+00	[JobBrief]{"hasVideo":true,"videoUrl":"https://homefix-b61f.onrender.com/uploads/b1ea718b-a111-408f-aa5b-308faa701169.mp4","categoryAnswers":{"What's the issue?":"New fitting/installation","Where is the problem?":"Main pipeline"}}	{https://homefix-b61f.onrender.com/uploads/579518db-b518-4d6a-8af4-ef86432cfa20.jpg}	pending	SRV-001085	9380	2026-09-04 08:56:18.043852	t	15	2026-09-19 08:56:38.471017+00	f	\N	\N	\N	f
f95e9d73-b233-4478-a084-8297a5a0b17d	aebfbed2-7205-437b-9045-65d1b0240e6a	ff7fa15e-6118-4cc5-9939-5d1e34799898	67870415-027c-4371-814b-3d80c0f67b7f	1dec1ea7-7e4a-4b07-97cd-844c5e86015d	accepted	fhjj\nhkrrsdc	\N	299.00	\N	2026-09-01 07:14:40.151461+00	2026-09-01 07:14:40.161824+00	[JobBrief]{"startedWhen":"Today","isContinuous":true,"previousRepair":false,"isEmergency":false}	\N	pending	SRV-001037	\N	\N	f	\N	\N	f	\N	\N	\N	f
92ebb125-533e-4092-a72f-3d7d1a850b72	aebfbed2-7205-437b-9045-65d1b0240e6a	e9977c7e-f0a5-4284-95a6-f535a31b0c9f	1951b819-8776-4183-80ab-ea271aac9e85	30dec4a6-9c9f-482f-8e2b-37e6853404dc	accepted		\N	299.00	\N	2026-09-02 04:52:51.856466+00	2026-09-02 04:52:51.860343+00	\N	\N	pending	SRV-001045	\N	\N	f	\N	\N	f	\N	\N	\N	f
edf7d099-aeb6-4acf-9e19-fad995abfb96	aebfbed2-7205-437b-9045-65d1b0240e6a	e9977c7e-f0a5-4284-95a6-f535a31b0c9f	1951b819-8776-4183-80ab-ea271aac9e85	30dec4a6-9c9f-482f-8e2b-37e6853404dc	cancelled		\N	299.00	\N	2026-09-01 11:22:58.995365+00	2026-09-02 05:20:12.502873+00	\N	\N	pending	SRV-001041	\N	\N	f	\N	\N	f	\N	\N	\N	f
de9638e9-bfe9-471d-b91e-908706f4e6d1	aebfbed2-7205-437b-9045-65d1b0240e6a	56e6825f-1d28-4030-9831-8179f43ed3a8	763c06cc-2221-40d6-93db-9557a7c47aec	1dec1ea7-7e4a-4b07-97cd-844c5e86015d	cancelled		\N	199.00	\N	2026-09-01 07:16:32.205064+00	2026-09-01 07:16:40.315974+00	\N	\N	pending	SRV-001038	\N	\N	f	\N	\N	f	\N	\N	\N	f
d6919e1e-3713-4ba7-aa47-852d496da26a	aebfbed2-7205-437b-9045-65d1b0240e6a	ff7fa15e-6118-4cc5-9939-5d1e34799898	67870415-027c-4371-814b-3d80c0f67b7f	30dec4a6-9c9f-482f-8e2b-37e6853404dc	accepted		\N	299.00	\N	2026-09-01 10:48:25.334461+00	2026-09-01 10:48:25.340151+00	[JobBrief]{"startedWhen":"Today","isContinuous":true,"previousRepair":false,"isEmergency":false,"aiDiagnosis":"{\\n  \\"possible_fault\\": \\"AC not cooling properly\\",\\n  \\"causes\\": [\\"low refrigerant\\", \\"clogged air filter\\"],\\n  \\"follow_up_questions\\": [\\"Is the AC blowing warm air?\\", \\"Any unusual noises from the unit?\\", \\"When did the issue start?\\"],\\n  \\"confidence_score\\": 30,\\n  \\"estimated_cost_min\\": 2500,\\n  \\"estimated_cost_max\\": 5500,\\n  \\"estimated_time_minutes\\": 45,\\n  \\"can_solve_remotely\\": false,\\n  \\"recommendation\\": \\"onsite\\"\\n}"}	\N	pending	SRV-001039	\N	\N	f	\N	\N	f	\N	\N	\N	f
069a4e97-aefb-4cc4-bfb0-ac69d75c7017	aebfbed2-7205-437b-9045-65d1b0240e6a	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	1dec1ea7-7e4a-4b07-97cd-844c5e86015d	accepted		\N	179.00	\N	2026-09-02 07:48:50.216125+00	2026-09-02 07:48:50.228447+00	\N	\N	pending	SRV-001048	\N	\N	f	\N	\N	f	\N	\N	\N	f
053e8dfd-cfb9-470d-995c-be55481732e0	aebfbed2-7205-437b-9045-65d1b0240e6a	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	30dec4a6-9c9f-482f-8e2b-37e6853404dc	accepted		2026-09-03 08:30:00+00	179.00	\N	2026-09-03 10:36:53.46323+00	2026-09-03 10:36:53.470291+00	[JobBrief]{"categoryAnswers":{"What's the issue?":"Blockage / clogging","Where is the problem?":"Overhead tank"}}	\N	pending	SRV-001074	\N	\N	f	\N	\N	f	\N	\N	\N	f
21c4ac3b-8dd8-41fa-95a9-acf978333671	aebfbed2-7205-437b-9045-65d1b0240e6a	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	30dec4a6-9c9f-482f-8e2b-37e6853404dc	accepted		\N	179.00	\N	2026-09-02 09:09:38.637005+00	2026-09-02 09:09:38.643621+00	\N	\N	pending	SRV-001050	\N	\N	f	\N	\N	f	\N	\N	\N	f
50ed0da7-a6ef-43ce-8f40-a1f79c284c22	aebfbed2-7205-437b-9045-65d1b0240e6a	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	1dec1ea7-7e4a-4b07-97cd-844c5e86015d	on_the_way	tugg	2026-09-17 08:30:00+00	179.00	\N	2026-09-03 08:08:18.95048+00	2026-09-03 11:47:00.361824+00	[JobBrief]{"categoryAnswers":{"What's the issue?":"New fitting/installation","Where is the problem?":"Bathroom"}}	\N	pending	SRV-001069	\N	\N	f	\N	\N	f	\N	\N	\N	f
de6289f8-f8c8-47c7-bfec-650c68178691	3be2026d-ea02-43f3-bc41-e0b3e9bb133c	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	ff6bd475-bd7d-4b77-b120-8a9f6d5d479f	on_the_way		\N	179.00	\N	2026-09-03 03:15:26.367448+00	2026-09-03 03:15:29.430887+00	\N	\N	pending	SRV-001053	\N	\N	f	\N	\N	f	\N	\N	\N	f
45de7d89-bd38-40c8-8735-f99d6c67a674	064fad8e-000a-4ed1-a447-160afea13815	56e6825f-1d28-4030-9831-8179f43ed3a8	763c06cc-2221-40d6-93db-9557a7c47aec	e3c80060-e10b-4942-b45c-b0706277a7bd	inspecting		\N	199.00	\N	2026-09-01 10:59:11.924597+00	2026-09-01 10:59:28.866089+00	\N	\N	pending	SRV-001040	0869	2026-09-01 10:59:28.8646	f	\N	\N	f	\N	\N	\N	f
d115aac1-8291-4fff-9010-dc78e5281247	aebfbed2-7205-437b-9045-65d1b0240e6a	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	30dec4a6-9c9f-482f-8e2b-37e6853404dc	accepted		\N	179.00	\N	2026-09-03 04:06:03.103226+00	2026-09-03 04:06:03.108626+00	\N	\N	pending	SRV-001056	\N	\N	f	\N	\N	f	\N	\N	\N	f
8627b7bb-ca01-484d-918d-fbd552855a4b	aebfbed2-7205-437b-9045-65d1b0240e6a	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	30dec4a6-9c9f-482f-8e2b-37e6853404dc	accepted		\N	179.00	\N	2026-09-03 05:32:18.169208+00	2026-09-03 05:32:18.18005+00	\N	\N	pending	SRV-001058	\N	\N	f	\N	\N	f	\N	\N	\N	f
8031861e-f08c-4431-8c05-b8fa2ca57f40	aebfbed2-7205-437b-9045-65d1b0240e6a	ff7fa15e-6118-4cc5-9939-5d1e34799898	67870415-027c-4371-814b-3d80c0f67b7f	30dec4a6-9c9f-482f-8e2b-37e6853404dc	accepted	hduebidbdusbshs	2026-09-04 03:30:00+00	299.00	\N	2026-09-04 05:31:05.649458+00	2026-09-04 05:31:05.661183+00	[JobBrief]{"categoryAnswers":{"What's the issue?":"Not cooling","AC type":"Split AC"}}	{https://homefix-b61f.onrender.com/uploads/e8ba1653-ba0e-422d-8ced-9935054c6c55.jpg}	pending	SRV-001082	\N	\N	f	\N	\N	f	\N	\N	\N	f
1b30f148-2d8f-4401-8d70-7a7d2311e88b	3be2026d-ea02-43f3-bc41-e0b3e9bb133c	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	ff6bd475-bd7d-4b77-b120-8a9f6d5d479f	accepted		\N	179.00	\N	2026-09-03 05:37:52.825207+00	2026-09-03 05:37:52.831795+00	\N	\N	pending	SRV-001061	\N	\N	f	\N	\N	f	\N	\N	\N	f
a0346c66-f6c1-466e-8f6d-4fd61c501153	064fad8e-000a-4ed1-a447-160afea13815	56e6825f-1d28-4030-9831-8179f43ed3a8	763c06cc-2221-40d6-93db-9557a7c47aec	e3c80060-e10b-4942-b45c-b0706277a7bd	inspecting		\N	199.00	\N	2026-09-01 11:23:41.515669+00	2026-09-01 11:23:52.18512+00	\N	\N	pending	SRV-001042	8878	2026-09-01 11:23:52.183342	f	\N	\N	f	\N	\N	\N	f
ffb0bbac-d969-49c0-b9f4-51c9ae747776	aebfbed2-7205-437b-9045-65d1b0240e6a	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	30dec4a6-9c9f-482f-8e2b-37e6853404dc	inspecting		2026-09-04 03:30:00+00	179.00	\N	2026-09-04 03:13:25.994575+00	2026-09-04 03:13:52.511625+00	[JobBrief]{"categoryAnswers":{"Where is the problem?":"Kitchen","What's the issue?":"Leakage"}}	\N	pending	SRV-001078	8393	2026-09-04 03:13:52.510123	f	\N	\N	f	\N	\N	\N	f
84bae57a-641a-4404-b616-866208e4dd33	aebfbed2-7205-437b-9045-65d1b0240e6a	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	30dec4a6-9c9f-482f-8e2b-37e6853404dc	repair_in_progress	tisidtkxtr7itti	2026-09-03 03:30:00+00	179.00	\N	2026-09-03 06:45:12.308454+00	2026-09-03 06:46:55.058713+00	\N	\N	pending	SRV-001064	3678	2026-09-03 06:46:55.057197	f	\N	\N	f	\N	\N	\N	f
030ece2b-efa3-4d52-8777-f6f4624825e2	aebfbed2-7205-437b-9045-65d1b0240e6a	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	30dec4a6-9c9f-482f-8e2b-37e6853404dc	inspecting		2026-09-04 08:30:00+00	179.00	\N	2026-09-04 04:09:25.304683+00	2026-09-04 04:09:40.154141+00	[JobBrief]{"categoryAnswers":{"What's the issue?":"Low water pressure","Where is the problem?":"Bathroom"}}	\N	pending	SRV-001080	5345	2026-09-04 04:09:40.152291	f	\N	\N	f	\N	\N	\N	f
782acec4-53bb-49b2-8795-313d35eb31ea	3be2026d-ea02-43f3-bc41-e0b3e9bb133c	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	ff6bd475-bd7d-4b77-b120-8a9f6d5d479f	accepted		2026-09-03 03:30:00+00	179.00	\N	2026-09-03 07:15:11.33781+00	2026-09-03 07:15:11.344334+00	\N	\N	pending	SRV-001065	\N	\N	f	\N	\N	f	\N	\N	\N	f
d41d3e67-58a8-4739-b603-915c37570718	3be2026d-ea02-43f3-bc41-e0b3e9bb133c	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	ff6bd475-bd7d-4b77-b120-8a9f6d5d479f	arrived	lrob	2026-09-04 03:30:00+00	179.00	\N	2026-09-03 07:17:52.620244+00	2026-09-03 07:18:00.167029+00	\N	\N	pending	SRV-001066	8199	\N	f	\N	\N	f	\N	\N	\N	f
1ac4424a-57da-4946-adf8-3260b1dcfe3c	aebfbed2-7205-437b-9045-65d1b0240e6a	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	30dec4a6-9c9f-482f-8e2b-37e6853404dc	completed		2026-09-04 07:12:00+00	179.00	179.00	2026-09-04 07:12:42.766546+00	2026-09-04 07:13:35.443385+00	[JobBrief]{"hasVideo":true,"videoUrl":"https://homefix-b61f.onrender.com/uploads/70dcecc8-ec72-4366-802d-546ab96878d5.mp4","categoryAnswers":{"What's the issue?":"Blockage / clogging","Where is the problem?":"Overhead tank"}}	\N	pending	SRV-001084	4170	2026-09-04 07:13:28.49513	t	7	2026-09-11 07:13:35.441652+00	f	\N	\N	\N	f
12dd8936-488e-48c8-8312-122fb8cc53f5	aebfbed2-7205-437b-9045-65d1b0240e6a	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	30dec4a6-9c9f-482f-8e2b-37e6853404dc	inspecting		2026-09-03 03:30:00+00	179.00	\N	2026-09-03 08:05:39.580732+00	2026-09-03 08:06:54.408438+00	[JobBrief]{"categoryAnswers":{"What's the issue?":"Leakage","Where is the problem?":"Kitchen"}}	\N	pending	SRV-001068	6449	2026-09-03 08:06:54.404043	f	\N	\N	f	\N	\N	\N	f
9a8facc2-f8c9-4721-aebb-45615a91aa2d	aebfbed2-7205-437b-9045-65d1b0240e6a	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	30dec4a6-9c9f-482f-8e2b-37e6853404dc	accepted	dtiditditxti	\N	499.00	\N	2026-09-04 09:03:53.754163+00	2026-09-04 09:03:53.837841+00		\N	pending	SRV-001086	\N	\N	f	\N	\N	f	\N	99.00	pending	f
86a89aef-ad60-4443-bd89-710892e93df4	aebfbed2-7205-437b-9045-65d1b0240e6a	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	30dec4a6-9c9f-482f-8e2b-37e6853404dc	on_the_way	b7egx8	2026-09-03 03:30:00+00	179.00	\N	2026-09-03 08:38:53.608872+00	2026-09-03 08:39:08.290681+00	[JobBrief]{"categoryAnswers":{"What's the issue?":"Leakage","Where is the problem?":"Kitchen"}}	\N	pending	SRV-001070	\N	\N	f	\N	\N	f	\N	\N	\N	f
bcde4eec-26b8-4c7a-b71a-bbb56a8b8c2b	aebfbed2-7205-437b-9045-65d1b0240e6a	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	30dec4a6-9c9f-482f-8e2b-37e6853404dc	inspecting		2026-09-03 03:30:00+00	179.00	\N	2026-09-03 08:39:21.364245+00	2026-09-03 08:39:42.806731+00	[JobBrief]{"categoryAnswers":{"Where is the problem?":"Kitchen","What's the issue?":"Leakage"}}	\N	pending	SRV-001071	2215	2026-09-03 08:39:42.805172	f	\N	\N	f	\N	\N	\N	f
5ccde187-b272-449f-8d77-cf20b2d50540	aebfbed2-7205-437b-9045-65d1b0240e6a	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	30dec4a6-9c9f-482f-8e2b-37e6853404dc	accepted		2026-09-03 03:30:00+00	179.00	\N	2026-09-03 08:40:37.536012+00	2026-09-03 08:40:37.539113+00	[JobBrief]{"categoryAnswers":{"What's the issue?":"New fitting/installation","Where is the problem?":"Bathroom"}}	\N	pending	SRV-001072	\N	\N	f	\N	\N	f	\N	\N	\N	f
\.


--
-- Data for Name: categories; Type: TABLE DATA; Schema: public; Owner: homefix_db_wuc1_user
--

COPY public.categories (id, name, description, icon_url, base_price, is_active, created_at, warranty_options) FROM stdin;
9d94bcc9-42f8-480c-9dc7-ad5f59bad17b	Electrician	Wiring, switches, fittings and electrical repairs	\N	199.00	t	2026-08-29 06:07:37.583221+00	{7,15,30,90}
297f8069-7bb8-4948-a50b-51cd88ba2998	Plumber	Leak fixes, pipe fitting and plumbing repairs	\N	179.00	t	2026-08-29 06:07:37.583221+00	{7,15,30,90}
67870415-027c-4371-814b-3d80c0f67b7f	AC Repair	AC servicing, gas refill and repairs	\N	299.00	t	2026-08-29 06:07:37.583221+00	{7,15,30,90}
997a9d99-74e1-4910-a81a-86e85994026c	Appliance Repair	Repair for washing machines, fridges and more	\N	249.00	t	2026-08-29 06:07:37.583221+00	{7,15,30,90}
5e2c4f29-c2b6-4b22-a343-fd6f99cba635	Roofer	Roof repair, waterproofing and maintenance	\N	349.00	t	2026-08-29 06:07:37.583221+00	{7,15,30,90}
763c06cc-2221-40d6-93db-9557a7c47aec	Carpenter	Furniture repair, fitting and woodwork	\N	199.00	t	2026-08-29 06:07:37.583221+00	{7,15,30,90}
1951b819-8776-4183-80ab-ea271aac9e85	Painter	Interior and exterior painting services	\N	299.00	t	2026-08-29 06:07:37.583221+00	{7,15,30,90}
9875e70c-eeff-4dca-9ed6-b36428366621	Refrigerator	Fridge repair, cooling issues and servicing	\N	279.00	t	2026-08-29 06:07:40.014531+00	{7,15,30,90}
5ee240f2-3119-4b38-8095-6a1a3e0f4071	RO Service	Water purifier installation, service and repair	\N	199.00	t	2026-08-29 06:07:40.014531+00	{7,15,30,90}
fe0b80e7-c29f-42fc-aa6b-f21062f7baba	CCTV	CCTV camera installation and repair	\N	399.00	t	2026-08-29 06:07:40.014531+00	{7,15,30,90}
a360fe15-94b7-4dc9-9ad3-964418c4c4b6	Home Cleaning	Deep cleaning and sanitization for your home	\N	349.00	t	2026-08-29 06:07:40.014531+00	{7,15,30,90}
\.


--
-- Data for Name: cms_announcements; Type: TABLE DATA; Schema: public; Owner: homefix_db_wuc1_user
--

COPY public.cms_announcements (id, title, body, is_active, starts_at, ends_at, created_at) FROM stdin;
\.


--
-- Data for Name: cms_banners; Type: TABLE DATA; Schema: public; Owner: homefix_db_wuc1_user
--

COPY public.cms_banners (id, title, image_url, link_url, sort_order, is_active, created_at) FROM stdin;
\.


--
-- Data for Name: cms_faqs; Type: TABLE DATA; Schema: public; Owner: homefix_db_wuc1_user
--

COPY public.cms_faqs (id, question, answer, sort_order, is_active, created_at) FROM stdin;
\.


--
-- Data for Name: cms_pages; Type: TABLE DATA; Schema: public; Owner: homefix_db_wuc1_user
--

COPY public.cms_pages (id, key, title, content, updated_by, updated_at) FROM stdin;
\.


--
-- Data for Name: consultations; Type: TABLE DATA; Schema: public; Owner: homefix_db_wuc1_user
--

COPY public.consultations (id, customer_id, technician_id, category_id, status, fee, duration_seconds, payment_status, escalated_booking_id, started_at, ended_at, created_at, updated_at, reconnect_count, connection_quality, rating, rating_comment, decline_reason, scheduled_at, recommendation_summary, recommendation_price, recommendation_status, recommendation_sent_at, note, area, ai_diagnosis_session_id) FROM stdin;
ab7e2487-fa99-4f17-8b3d-6fc7d4b41fbc	dc3f702c-b385-4c27-9057-0325c0b5013d	ff7fa15e-6118-4cc5-9939-5d1e34799898	67870415-027c-4371-814b-3d80c0f67b7f	accepted	0.00	\N	pending	\N	\N	\N	2026-08-29 06:48:52.350141+00	2026-08-29 06:48:58.720943+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
95151443-417a-40ee-b10e-e8f3c0908a31	aebfbed2-7205-437b-9045-65d1b0240e6a	56e6825f-1d28-4030-9831-8179f43ed3a8	763c06cc-2221-40d6-93db-9557a7c47aec	cancelled	0.00	\N	pending	\N	\N	\N	2026-08-31 04:35:54.453619+00	2026-08-31 04:35:59.458359+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
5d566b57-d620-4a17-85ce-1dd2e78c61dc	dc3f702c-b385-4c27-9057-0325c0b5013d	ff7fa15e-6118-4cc5-9939-5d1e34799898	67870415-027c-4371-814b-3d80c0f67b7f	accepted	0.00	\N	pending	\N	\N	\N	2026-08-29 06:49:30.562266+00	2026-08-29 06:49:36.807454+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
559f6231-67d3-4f15-91ce-f66db43600fa	aebfbed2-7205-437b-9045-65d1b0240e6a	56e6825f-1d28-4030-9831-8179f43ed3a8	763c06cc-2221-40d6-93db-9557a7c47aec	cancelled	0.00	\N	pending	\N	\N	\N	2026-08-31 04:39:47.393024+00	2026-08-31 04:39:49.278899+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
f406d5a0-939b-45df-b4a5-cb099d5420b7	aebfbed2-7205-437b-9045-65d1b0240e6a	e9977c7e-f0a5-4284-95a6-f535a31b0c9f	1951b819-8776-4183-80ab-ea271aac9e85	cancelled	0.00	\N	pending	\N	\N	\N	2026-08-29 07:22:26.812744+00	2026-08-29 07:22:39.619352+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
2036db4d-cdd6-4986-9bad-2ac482dad2c3	aebfbed2-7205-437b-9045-65d1b0240e6a	e9977c7e-f0a5-4284-95a6-f535a31b0c9f	1951b819-8776-4183-80ab-ea271aac9e85	accepted	0.00	\N	pending	\N	\N	\N	2026-08-29 07:22:53.25983+00	2026-08-29 07:22:59.614312+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
468c9dcb-6560-4575-9aae-916a81f4ef6d	aebfbed2-7205-437b-9045-65d1b0240e6a	56e6825f-1d28-4030-9831-8179f43ed3a8	763c06cc-2221-40d6-93db-9557a7c47aec	cancelled	0.00	\N	pending	\N	\N	\N	2026-08-31 04:44:30.127999+00	2026-08-31 04:44:35.301989+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
bf67913f-43f9-4670-a4df-627a23439468	4f3d12f3-d8a6-4c97-8016-2d44b252426f	ff7fa15e-6118-4cc5-9939-5d1e34799898	67870415-027c-4371-814b-3d80c0f67b7f	cancelled	0.00	\N	pending	\N	\N	\N	2026-08-29 07:50:31.013617+00	2026-08-29 07:50:32.208888+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
e90fc5b4-f6b7-4048-8431-3eccf66fa7ce	4f3d12f3-d8a6-4c97-8016-2d44b252426f	ff7fa15e-6118-4cc5-9939-5d1e34799898	67870415-027c-4371-814b-3d80c0f67b7f	ringing	0.00	\N	pending	\N	\N	\N	2026-08-29 07:50:33.271243+00	2026-08-29 07:50:33.273495+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
c288da0a-2893-43d9-9837-2a512078caf3	aebfbed2-7205-437b-9045-65d1b0240e6a	56e6825f-1d28-4030-9831-8179f43ed3a8	763c06cc-2221-40d6-93db-9557a7c47aec	cancelled	0.00	\N	pending	\N	\N	\N	2026-08-31 04:53:12.152062+00	2026-08-31 04:53:15.813453+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
0c773879-f515-475d-b36e-71c90ce3d441	4f3d12f3-d8a6-4c97-8016-2d44b252426f	ff7fa15e-6118-4cc5-9939-5d1e34799898	67870415-027c-4371-814b-3d80c0f67b7f	cancelled	0.00	\N	pending	\N	\N	\N	2026-08-29 07:50:56.973685+00	2026-08-29 07:51:07.775574+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
0abd7750-b49c-47e6-aa38-2678caab7813	aebfbed2-7205-437b-9045-65d1b0240e6a	56e6825f-1d28-4030-9831-8179f43ed3a8	763c06cc-2221-40d6-93db-9557a7c47aec	cancelled	0.00	\N	pending	\N	\N	\N	2026-08-31 04:55:55.800725+00	2026-08-31 04:56:00.792723+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
c8df6adb-01ef-4600-a9c9-bd8a80677375	5978c7ed-c201-40f9-ac16-08fcb5d81431	ff7fa15e-6118-4cc5-9939-5d1e34799898	67870415-027c-4371-814b-3d80c0f67b7f	cancelled	0.00	\N	pending	\N	\N	\N	2026-08-29 08:06:03.101988+00	2026-08-29 08:08:07.22038+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
13cbf778-2d02-4ee9-97c0-1661b8c9094a	5978c7ed-c201-40f9-ac16-08fcb5d81431	ff7fa15e-6118-4cc5-9939-5d1e34799898	67870415-027c-4371-814b-3d80c0f67b7f	cancelled	0.00	\N	pending	\N	\N	\N	2026-08-29 08:09:35.484263+00	2026-08-29 08:09:36.416974+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
3f4fa8b4-e396-4f38-89f9-ccc4ff06bdcf	5978c7ed-c201-40f9-ac16-08fcb5d81431	56e6825f-1d28-4030-9831-8179f43ed3a8	763c06cc-2221-40d6-93db-9557a7c47aec	accepted	0.00	\N	pending	\N	\N	\N	2026-08-29 08:11:11.399475+00	2026-08-29 08:11:25.354895+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
c454e826-959d-4f3c-874c-079e437ef12c	aebfbed2-7205-437b-9045-65d1b0240e6a	56e6825f-1d28-4030-9831-8179f43ed3a8	763c06cc-2221-40d6-93db-9557a7c47aec	cancelled	0.00	\N	pending	\N	\N	\N	2026-08-31 05:23:56.862355+00	2026-08-31 05:23:57.799527+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
0c027092-7a03-4847-a74a-c6067ff5d428	aebfbed2-7205-437b-9045-65d1b0240e6a	56e6825f-1d28-4030-9831-8179f43ed3a8	763c06cc-2221-40d6-93db-9557a7c47aec	rejected	0.00	\N	pending	\N	\N	\N	2026-08-31 05:22:28.197241+00	2026-08-31 05:25:08.858028+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
80b27655-eb13-42bd-bd43-69235b6a0aca	5978c7ed-c201-40f9-ac16-08fcb5d81431	56e6825f-1d28-4030-9831-8179f43ed3a8	763c06cc-2221-40d6-93db-9557a7c47aec	accepted	0.00	\N	pending	\N	\N	\N	2026-08-29 08:12:35.45097+00	2026-08-29 08:13:09.697056+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
7e4e3641-1cd1-407e-8468-5f1e68f37241	4f3d12f3-d8a6-4c97-8016-2d44b252426f	56e6825f-1d28-4030-9831-8179f43ed3a8	763c06cc-2221-40d6-93db-9557a7c47aec	cancelled	0.00	\N	pending	\N	\N	\N	2026-08-29 08:40:21.259851+00	2026-08-29 08:40:22.86092+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
63a8a962-1979-4f36-be10-3bc2233275bd	aebfbed2-7205-437b-9045-65d1b0240e6a	56e6825f-1d28-4030-9831-8179f43ed3a8	763c06cc-2221-40d6-93db-9557a7c47aec	cancelled	0.00	\N	pending	\N	\N	\N	2026-08-31 06:22:12.609803+00	2026-08-31 06:22:13.701749+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
9b61cba5-8cda-4e47-977f-d24c2c00651b	ef023969-5324-493a-ad92-0ce013f4a1ca	ff7fa15e-6118-4cc5-9939-5d1e34799898	67870415-027c-4371-814b-3d80c0f67b7f	cancelled	0.00	\N	pending	\N	\N	\N	2026-08-29 08:47:11.87469+00	2026-08-29 08:47:51.233784+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
afe18add-0154-4533-9029-11dd434cc1d3	aebfbed2-7205-437b-9045-65d1b0240e6a	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	accepted	0.00	\N	pending	\N	\N	\N	2026-08-31 07:57:44.448917+00	2026-08-31 07:58:51.601139+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
c21c3e19-f8f0-4a12-a18a-41a3fdc3107b	aebfbed2-7205-437b-9045-65d1b0240e6a	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	accepted	0.00	\N	pending	\N	\N	\N	2026-08-31 08:49:42.506058+00	2026-08-31 08:51:58.136607+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
39277fea-09d8-4c3c-b033-96095b7ffed5	aebfbed2-7205-437b-9045-65d1b0240e6a	e9977c7e-f0a5-4284-95a6-f535a31b0c9f	1951b819-8776-4183-80ab-ea271aac9e85	ringing	0.00	\N	pending	\N	\N	\N	2026-08-29 11:03:54.867888+00	2026-08-29 11:03:54.871534+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
f2469e92-31c7-49fa-8f51-48dc12fb4146	aebfbed2-7205-437b-9045-65d1b0240e6a	e9977c7e-f0a5-4284-95a6-f535a31b0c9f	1951b819-8776-4183-80ab-ea271aac9e85	ended	0.00	0	pending	08c5ea8e-e260-4e2d-b604-be16d8092334	\N	2026-08-29 11:03:56.603919+00	2026-08-29 10:59:40.173618+00	2026-08-29 11:03:56.603919+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
8880da0d-689b-4a3b-b03e-b592b16ba970	aebfbed2-7205-437b-9045-65d1b0240e6a	\N	67870415-027c-4371-814b-3d80c0f67b7f	searching	0.00	\N	pending	\N	\N	\N	2026-09-01 07:00:34.745443+00	2026-09-01 07:00:34.745443+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
0313da23-927f-470c-b801-33ac3c6cec69	aebfbed2-7205-437b-9045-65d1b0240e6a	\N	67870415-027c-4371-814b-3d80c0f67b7f	searching	0.00	\N	pending	\N	\N	\N	2026-09-01 07:14:28.228647+00	2026-09-01 07:14:28.228647+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
0029ec35-42ce-4e16-929f-5b35b8f7dad6	aebfbed2-7205-437b-9045-65d1b0240e6a	ff7fa15e-6118-4cc5-9939-5d1e34799898	67870415-027c-4371-814b-3d80c0f67b7f	cancelled	0.00	\N	pending	\N	\N	\N	2026-08-29 17:55:31.363765+00	2026-08-29 17:55:32.531232+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
bdf58b9c-45f8-4f83-88a0-443ae58ea113	aebfbed2-7205-437b-9045-65d1b0240e6a	\N	1951b819-8776-4183-80ab-ea271aac9e85	searching	0.00	\N	pending	\N	\N	\N	2026-09-01 07:42:26.247986+00	2026-09-01 07:42:26.247986+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
aa41ee94-3163-4455-bd2c-c6396d30968c	aebfbed2-7205-437b-9045-65d1b0240e6a	\N	997a9d99-74e1-4910-a81a-86e85994026c	no_technician	0.00	\N	pending	\N	\N	\N	2026-08-30 01:06:51.378147+00	2026-08-30 01:06:51.383231+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
599a8e7f-7ea5-4afe-bfe3-cf68417240df	aebfbed2-7205-437b-9045-65d1b0240e6a	\N	1951b819-8776-4183-80ab-ea271aac9e85	searching	0.00	\N	pending	\N	\N	\N	2026-09-01 07:42:28.091493+00	2026-09-01 07:42:28.091493+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
8f26d87e-7dd5-4170-8a70-225a8e52a3df	aebfbed2-7205-437b-9045-65d1b0240e6a	e9977c7e-f0a5-4284-95a6-f535a31b0c9f	1951b819-8776-4183-80ab-ea271aac9e85	cancelled	0.00	\N	pending	\N	\N	\N	2026-08-30 02:48:14.287044+00	2026-08-30 02:48:16.586931+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
9ee66fb0-6c9a-4d85-bd45-8510e678e5b5	aebfbed2-7205-437b-9045-65d1b0240e6a	\N	1951b819-8776-4183-80ab-ea271aac9e85	searching	0.00	\N	pending	\N	\N	\N	2026-09-01 07:42:39.092442+00	2026-09-01 07:42:39.092442+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
05906ef0-9ce7-450a-8a85-67e2ee04e51a	aebfbed2-7205-437b-9045-65d1b0240e6a	\N	67870415-027c-4371-814b-3d80c0f67b7f	searching	0.00	\N	pending	\N	\N	\N	2026-09-01 07:42:45.308145+00	2026-09-01 07:42:45.308145+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
c11573ec-d50d-4259-b19b-c71b5934c4bc	aebfbed2-7205-437b-9045-65d1b0240e6a	e9977c7e-f0a5-4284-95a6-f535a31b0c9f	1951b819-8776-4183-80ab-ea271aac9e85	cancelled	0.00	\N	pending	\N	\N	\N	2026-08-30 03:22:16.980255+00	2026-08-30 03:22:17.942966+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
f3de788e-7f26-4e05-953e-44cdf0fd334b	aebfbed2-7205-437b-9045-65d1b0240e6a	\N	67870415-027c-4371-814b-3d80c0f67b7f	searching	0.00	\N	pending	\N	\N	\N	2026-09-01 07:42:47.768035+00	2026-09-01 07:42:47.768035+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
498f09d2-536a-4564-ac9d-ed33713f9557	aebfbed2-7205-437b-9045-65d1b0240e6a	\N	763c06cc-2221-40d6-93db-9557a7c47aec	searching	0.00	\N	pending	\N	\N	\N	2026-09-01 07:42:53.465461+00	2026-09-01 07:42:53.465461+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
f0199c14-07f8-46ae-8ab5-549e5134e874	aebfbed2-7205-437b-9045-65d1b0240e6a	56e6825f-1d28-4030-9831-8179f43ed3a8	763c06cc-2221-40d6-93db-9557a7c47aec	cancelled	0.00	\N	pending	\N	\N	\N	2026-08-30 03:22:49.374474+00	2026-08-30 03:22:50.316635+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
3b5c7eb6-933f-49d2-96ff-596a2d275d90	aebfbed2-7205-437b-9045-65d1b0240e6a	\N	763c06cc-2221-40d6-93db-9557a7c47aec	searching	0.00	\N	pending	\N	\N	\N	2026-09-01 07:42:55.508834+00	2026-09-01 07:42:55.508834+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
95fa8c22-92d9-4c69-a961-d259c6cc3c3d	aebfbed2-7205-437b-9045-65d1b0240e6a	\N	1951b819-8776-4183-80ab-ea271aac9e85	searching	0.00	\N	pending	\N	\N	\N	2026-09-01 07:55:18.422036+00	2026-09-01 07:55:18.422036+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
1ef4c97c-2aaa-408a-bf87-d33cddcd12d2	aebfbed2-7205-437b-9045-65d1b0240e6a	e9977c7e-f0a5-4284-95a6-f535a31b0c9f	1951b819-8776-4183-80ab-ea271aac9e85	cancelled	0.00	\N	pending	\N	\N	\N	2026-08-30 18:08:58.313492+00	2026-08-30 18:09:00.050399+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
6ab58297-45bb-4ddf-b1aa-fa8fc507321d	aebfbed2-7205-437b-9045-65d1b0240e6a	\N	1951b819-8776-4183-80ab-ea271aac9e85	searching	0.00	\N	pending	\N	\N	\N	2026-09-01 07:55:21.28979+00	2026-09-01 07:55:21.28979+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
b94b408d-85c4-4951-b1f3-8882b9131014	aebfbed2-7205-437b-9045-65d1b0240e6a	ff7fa15e-6118-4cc5-9939-5d1e34799898	67870415-027c-4371-814b-3d80c0f67b7f	cancelled	0.00	\N	pending	\N	\N	\N	2026-08-30 18:15:39.233766+00	2026-08-30 18:15:52.495445+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
9947a7b6-d435-49a7-a56b-e09a4fa4b389	aebfbed2-7205-437b-9045-65d1b0240e6a	56e6825f-1d28-4030-9831-8179f43ed3a8	763c06cc-2221-40d6-93db-9557a7c47aec	cancelled	0.00	\N	pending	\N	\N	\N	2026-09-01 08:05:31.066298+00	2026-09-01 08:05:32.875619+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
42b04f77-9ac1-4e3b-badd-37be365c30a2	aebfbed2-7205-437b-9045-65d1b0240e6a	56e6825f-1d28-4030-9831-8179f43ed3a8	763c06cc-2221-40d6-93db-9557a7c47aec	cancelled	0.00	\N	pending	\N	\N	\N	2026-08-30 18:16:03.500825+00	2026-08-30 18:16:11.717288+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
7d07fa54-0cb3-4d1a-bfb1-602155c1710b	aebfbed2-7205-437b-9045-65d1b0240e6a	56e6825f-1d28-4030-9831-8179f43ed3a8	763c06cc-2221-40d6-93db-9557a7c47aec	ended	0.00	0	pending	68bc8edb-976c-4030-bc76-89486f0ea45c	\N	2026-08-30 18:17:04.460769+00	2026-08-30 18:16:31.697098+00	2026-08-30 18:17:25.36615+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
3a14e134-43bf-4adc-8772-45446ca5cb0f	aebfbed2-7205-437b-9045-65d1b0240e6a	ff7fa15e-6118-4cc5-9939-5d1e34799898	67870415-027c-4371-814b-3d80c0f67b7f	cancelled	0.00	\N	pending	\N	\N	\N	2026-08-31 03:10:46.256431+00	2026-08-31 03:10:47.777174+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
9bbacdaf-39a8-4e50-8d21-c5c0ff1b5ebd	aebfbed2-7205-437b-9045-65d1b0240e6a	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	confirmed	0.00	\N	pending	\N	\N	\N	2026-09-01 08:48:31.064904+00	2026-09-01 08:48:31.070084+00	0	\N	\N	\N	\N	2026-09-02 07:00:00+00	\N	\N	\N	\N	\N	\N	\N
13ae1d53-e0ad-456c-ad56-12831b099445	aebfbed2-7205-437b-9045-65d1b0240e6a	ff7fa15e-6118-4cc5-9939-5d1e34799898	67870415-027c-4371-814b-3d80c0f67b7f	cancelled	0.00	\N	pending	\N	\N	\N	2026-08-31 03:55:56.378662+00	2026-08-31 03:55:57.580431+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
fb2a6026-2ab4-467b-bbed-8fdd7ee42172	aebfbed2-7205-437b-9045-65d1b0240e6a	56e6825f-1d28-4030-9831-8179f43ed3a8	763c06cc-2221-40d6-93db-9557a7c47aec	cancelled	0.00	\N	pending	\N	\N	\N	2026-08-31 04:20:06.661898+00	2026-08-31 04:20:10.104613+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
ec84b5a0-f6f7-4608-9ee7-c9e2b30d3978	aebfbed2-7205-437b-9045-65d1b0240e6a	ff7fa15e-6118-4cc5-9939-5d1e34799898	67870415-027c-4371-814b-3d80c0f67b7f	cancelled	0.00	\N	pending	\N	\N	\N	2026-09-01 08:57:43.532005+00	2026-09-01 08:57:45.999739+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
ff45f98d-8a40-47b0-aa0a-536f15d87e42	aebfbed2-7205-437b-9045-65d1b0240e6a	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	ended	0.00	0	pending	\N	\N	2026-09-01 09:02:21.73878+00	2026-09-01 09:01:57.597199+00	2026-09-01 09:02:21.73878+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
e4ac66d3-28a0-441b-8d92-4df78f7da25c	aebfbed2-7205-437b-9045-65d1b0240e6a	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	ended	0.00	0	pending	\N	\N	2026-09-01 08:45:53.472547+00	2026-09-01 08:45:06.089392+00	2026-09-01 09:42:23.227426+00	0	\N	\N	\N	\N	\N	ac cooling issue	299.00	declined	2026-09-01 08:46:54.73306	\N	\N	\N
13b130a9-e40d-4385-a9c1-edd358e93160	aebfbed2-7205-437b-9045-65d1b0240e6a	ff7fa15e-6118-4cc5-9939-5d1e34799898	67870415-027c-4371-814b-3d80c0f67b7f	cancelled	0.00	\N	pending	\N	\N	\N	2026-09-01 09:51:20.861707+00	2026-09-01 09:51:21.976954+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
614f30f5-ae43-4876-9c7e-4186c4e51f9c	9dd63068-5ba2-487e-ab79-aa0bb4f686f5	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	ended	0.00	0	pending	9a29e88d-004c-42d5-84b1-e48bb8c9dd06	\N	2026-09-04 02:35:58.993447+00	2026-09-04 02:35:37.572022+00	2026-09-04 02:37:11.751092+00	0	\N	\N	\N	\N	\N	vehdubd	258.00	accepted	2026-09-04 02:36:12.704692	hd	gr	\N
d711424a-e678-452b-b47e-a9d504208158	064fad8e-000a-4ed1-a447-160afea13815	ff7fa15e-6118-4cc5-9939-5d1e34799898	67870415-027c-4371-814b-3d80c0f67b7f	confirmed	0.00	\N	pending	\N	\N	\N	2026-09-01 11:28:39.828003+00	2026-09-01 11:28:39.83302+00	0	\N	\N	\N	\N	2026-09-01 12:28:00+00	\N	\N	\N	\N	\N	\N	\N
ba2519c2-8112-4ee3-ace6-bf1ead3e1783	aebfbed2-7205-437b-9045-65d1b0240e6a	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	rejected	0.00	\N	pending	\N	\N	\N	2026-09-03 11:48:24.524287+00	2026-09-04 04:11:02.234354+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	hehdb	heudjeb	\N
a686447d-43cc-4a26-b10e-a299cb7224bb	aebfbed2-7205-437b-9045-65d1b0240e6a	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	ended	0.00	0	pending	\N	\N	2026-09-04 07:05:20.693512+00	2026-09-03 11:48:40.197382+00	2026-09-04 07:05:20.693512+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	jugh	hhghjj	\N
98afd057-ed8a-4eec-9168-3c82c0dab672	3be2026d-ea02-43f3-bc41-e0b3e9bb133c	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	ended	0.00	0	pending	\N	\N	2026-09-03 03:16:20.689252+00	2026-09-03 03:15:53.730016+00	2026-09-03 03:16:20.689252+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
dcb15e78-261e-4cd1-9fab-ba5f1d25f88d	aebfbed2-7205-437b-9045-65d1b0240e6a	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	cancelled	0.00	\N	pending	\N	\N	\N	2026-09-04 08:58:50.814208+00	2026-09-04 08:59:03.258568+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	hjgv	rhihh	\N
851c31df-9c1a-436d-9b76-ec5b19ef40fe	aebfbed2-7205-437b-9045-65d1b0240e6a	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	ended	0.00	0	pending	\N	\N	2026-09-04 08:59:13.487785+00	2026-09-04 02:13:50.742624+00	2026-09-04 08:59:13.487785+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	6bn	fiih	\N
42dabaed-2a39-4814-a067-8c78d776d5fe	9dd63068-5ba2-487e-ab79-aa0bb4f686f5	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	ended	0.00	0	pending	c0caeee6-61ff-4109-991d-dc8705ea41d3	\N	2026-09-04 02:34:55.118903+00	2026-09-04 02:34:08.715975+00	2026-09-04 02:35:21.262321+00	0	\N	3	\N	\N	\N	\N	\N	\N	\N	my water gets flow	navi mumbai	\N
6916eed6-597f-468d-bfcf-fc0f1ea783fd	3be2026d-ea02-43f3-bc41-e0b3e9bb133c	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	ended	0.00	0	pending	c2e3fd6f-14b7-4147-87ff-a7f78d92592e	\N	2026-09-03 03:16:52.940739+00	2026-09-03 03:16:33.781533+00	2026-09-03 03:17:41.018496+00	0	\N	\N	\N	\N	\N	iegxirgxirgir	299.00	accepted	2026-09-03 03:17:06.469926	\N	\N	\N
fc5b82a7-8f4f-4f49-a342-cc34776ee130	3be2026d-ea02-43f3-bc41-e0b3e9bb133c	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	confirmed	0.00	\N	pending	\N	\N	\N	2026-09-03 03:21:48.379778+00	2026-09-03 03:21:48.382689+00	0	\N	\N	\N	\N	2026-09-03 19:00:00+00	\N	\N	\N	\N	\N	\N	\N
a8501454-e22a-4600-8170-5a10ce8e639e	3be2026d-ea02-43f3-bc41-e0b3e9bb133c	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	cancelled	0.00	\N	pending	\N	\N	\N	2026-09-03 05:54:58.534701+00	2026-09-03 05:54:59.501714+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
41c44d17-6822-4eeb-88a9-c00a686f40b9	aebfbed2-7205-437b-9045-65d1b0240e6a	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	confirmed	0.00	\N	pending	\N	\N	\N	2026-09-03 06:37:24.246382+00	2026-09-03 06:37:24.25083+00	0	\N	\N	\N	\N	2026-09-03 07:37:00+00	\N	\N	\N	\N	\N	\N	\N
0fc55c02-7993-4298-8e1e-68d6e4147321	3be2026d-ea02-43f3-bc41-e0b3e9bb133c	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	cancelled	0.00	\N	pending	\N	\N	\N	2026-09-03 07:14:22.290052+00	2026-09-03 07:14:23.020804+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
82d91fe5-5e12-4ef6-a973-ac2ba17de0a5	aebfbed2-7205-437b-9045-65d1b0240e6a	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	ended	0.00	0	pending	9a8facc2-f8c9-4721-aebb-45615a91aa2d	\N	2026-09-04 08:59:41.53123+00	2026-09-04 08:59:18.447614+00	2026-09-04 09:03:53.839881+00	0	\N	\N	\N	\N	\N	dtiditditxti	499.00	accepted	2026-09-04 09:03:26.834775	ryyg	3ghgg	\N
bf98f7d6-008b-49f2-a552-85d41c210bf4	aebfbed2-7205-437b-9045-65d1b0240e6a	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	rejected	0.00	\N	pending	\N	\N	\N	2026-09-03 09:18:35.473969+00	2026-09-03 09:19:33.823136+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
56010871-f310-48d9-9364-329f8cb9340b	aebfbed2-7205-437b-9045-65d1b0240e6a	\N	297f8069-7bb8-4948-a50b-51cd88ba2998	searching	0.00	\N	pending	\N	\N	\N	2026-09-03 11:40:34.912472+00	2026-09-03 11:40:34.912472+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	hdhdb	heuudbr	\N
bdcc241b-a4b9-4c1e-a482-3e65bb0b4fc2	aebfbed2-7205-437b-9045-65d1b0240e6a	e894f942-a1c6-420d-801f-0f73b8921856	297f8069-7bb8-4948-a50b-51cd88ba2998	cancelled	0.00	\N	pending	\N	\N	\N	2026-09-04 02:28:54.191885+00	2026-09-04 02:29:00.037506+00	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	uggjbb	gyujhb	\N
\.


--
-- Data for Name: dispute_evidence; Type: TABLE DATA; Schema: public; Owner: homefix_db_wuc1_user
--

COPY public.dispute_evidence (id, dispute_id, uploaded_by, file_url, note, created_at) FROM stdin;
480276d8-a4b8-407e-8147-af053106d35a	cb8aca0d-d0eb-49de-8e43-b0013af10b08	aebfbed2-7205-437b-9045-65d1b0240e6a	https://homefix-b61f.onrender.com/uploads/47c56b35-d017-4bbb-8487-6e3529a8b47d.jpg	d5d5d5d	2026-09-02 05:20:42.937085+00
ad2c94db-7b35-475c-9f6b-c6c24b633fb9	9b1eb6c2-48e9-4e52-b157-0abb3452ca1b	aebfbed2-7205-437b-9045-65d1b0240e6a	https://homefix-b61f.onrender.com/uploads/fdd7d3af-0a3e-4ff4-948e-b4bd6d958012.jpg	jeiejididjehdydbri	2026-09-02 05:26:25.951364+00
\.


--
-- Data for Name: disputes; Type: TABLE DATA; Schema: public; Owner: homefix_db_wuc1_user
--

COPY public.disputes (id, booking_id, consultation_id, raised_by, reason, status, refund_amount, admin_notes, resolved_by, resolved_at, created_at, updated_at) FROM stdin;
c60a695a-d3ca-4040-8a76-659aac431651	ad934dd3-d075-4515-8acf-92c82c2b0e6d	\N	aebfbed2-7205-437b-9045-65d1b0240e6a	bdishdjebdyej	open	\N	\N	\N	\N	2026-09-02 04:53:42.307213+00	2026-09-02 04:53:42.307213+00
cb8aca0d-d0eb-49de-8e43-b0013af10b08	edf7d099-aeb6-4acf-9e19-fad995abfb96	\N	aebfbed2-7205-437b-9045-65d1b0240e6a	fyuot7y7r6e6f7t7	open	\N	\N	\N	\N	2026-09-02 05:20:28.965936+00	2026-09-02 05:20:28.965936+00
9b1eb6c2-48e9-4e52-b157-0abb3452ca1b	b16efaa0-4d95-4044-b794-62e407559ac6	\N	aebfbed2-7205-437b-9045-65d1b0240e6a	hdudnidndndiejdjd	open	\N	\N	\N	\N	2026-09-02 05:26:10.192025+00	2026-09-02 05:26:10.192025+00
\.


--
-- Data for Name: notifications; Type: TABLE DATA; Schema: public; Owner: homefix_db_wuc1_user
--

COPY public.notifications (id, user_id, title, body, data, is_read, sent_via_fcm, created_at) FROM stdin;
0de991aa-517b-4a37-9d83-8721f500d9d9	3e09db72-8f82-49c5-81b4-b95be21ea46f	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "e70405d7-2471-42eb-b587-8f8242a67a01"}	f	f	2026-08-29 06:47:01.05254+00
3594f73c-55b6-483b-9a1a-8d7da22623a9	dc3f702c-b385-4c27-9057-0325c0b5013d	Booking update	Your booking status changed to in_progress	{"type": "booking_status", "booking_id": "e70405d7-2471-42eb-b587-8f8242a67a01"}	f	f	2026-08-29 06:47:37.90366+00
96ca627b-55c9-4173-b394-dce9477f397d	dc3f702c-b385-4c27-9057-0325c0b5013d	Invoice ready	Your technician has completed the job. Amount due: ₹299.00. Tap to pay.	{"type": "invoice_ready", "booking_id": "e70405d7-2471-42eb-b587-8f8242a67a01", "final_price": "299.00"}	f	f	2026-08-29 06:47:45.228298+00
f61e13c0-b923-4bf9-ad78-6512be4378c0	3e09db72-8f82-49c5-81b4-b95be21ea46f	New consultation request	A customer has requested a live video consultation with you.	{"type": "consultation_request", "consultation_id": "ab7e2487-fa99-4f17-8b3d-6fc7d4b41fbc"}	f	f	2026-08-29 06:48:52.395388+00
4455d51f-9da6-43cd-88e9-5de605896829	dc3f702c-b385-4c27-9057-0325c0b5013d	Consultation accepted	A technician has accepted your live video consultation. Connecting now...	{"type": "consultation_accepted", "consultation_id": "ab7e2487-fa99-4f17-8b3d-6fc7d4b41fbc"}	f	f	2026-08-29 06:48:58.722914+00
b00a2cfd-79c8-4d9a-989a-d4173b470578	3e09db72-8f82-49c5-81b4-b95be21ea46f	New consultation request	A customer has requested a live video consultation with you.	{"type": "consultation_request", "consultation_id": "5d566b57-d620-4a17-85ce-1dd2e78c61dc"}	f	f	2026-08-29 06:49:30.567068+00
a15761c4-bc1f-455f-98da-8c035f7c43bc	dc3f702c-b385-4c27-9057-0325c0b5013d	Consultation accepted	A technician has accepted your live video consultation. Connecting now...	{"type": "consultation_accepted", "consultation_id": "5d566b57-d620-4a17-85ce-1dd2e78c61dc"}	f	f	2026-08-29 06:49:36.809596+00
21479018-7ea4-4b97-b35d-4159b4cf896c	dc3f702c-b385-4c27-9057-0325c0b5013d	New message	Hello pratiksha	{"type": "booking_message", "booking_id": "e70405d7-2471-42eb-b587-8f8242a67a01"}	f	f	2026-08-29 06:50:04.213462+00
0d9b2807-57b4-4d00-a6f5-0b2eb551154b	3e09db72-8f82-49c5-81b4-b95be21ea46f	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "5d859f37-e87a-4369-8d52-1c94d9f837d5"}	f	f	2026-08-29 07:05:18.259994+00
91c6785d-071d-4ec5-be4c-6178fb7caa82	dc3f702c-b385-4c27-9057-0325c0b5013d	Booking update	Your booking status changed to in_progress	{"type": "booking_status", "booking_id": "5d859f37-e87a-4369-8d52-1c94d9f837d5"}	f	f	2026-08-29 07:13:42.988372+00
262b9ae2-4165-4851-8c75-c7e244bd6cd7	dc3f702c-b385-4c27-9057-0325c0b5013d	Invoice ready	Your technician has completed the job. Amount due: ₹299.00. Tap to pay.	{"type": "invoice_ready", "booking_id": "5d859f37-e87a-4369-8d52-1c94d9f837d5", "final_price": "299.00"}	f	f	2026-08-29 07:13:48.923175+00
11002246-6066-4afb-991c-bae2db1509e5	8ce31a51-34d2-45ac-bbdd-0069413f6b3a	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "6159f686-4eca-4829-8984-8d748016d126"}	f	f	2026-08-29 07:21:49.282625+00
213c7f03-7065-422c-8b99-81e765601487	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to in_progress	{"type": "booking_status", "booking_id": "6159f686-4eca-4829-8984-8d748016d126"}	f	f	2026-08-29 07:22:02.206268+00
35fb10ba-3421-4ae3-817d-fe2ff6d69837	aebfbed2-7205-437b-9045-65d1b0240e6a	Invoice ready	Your technician has completed the job. Amount due: ₹399.00. Tap to pay.	{"type": "invoice_ready", "booking_id": "6159f686-4eca-4829-8984-8d748016d126", "final_price": "399.00"}	f	f	2026-08-29 07:22:10.42924+00
70f8300b-d795-4692-a6b2-3c1e70e32137	8ce31a51-34d2-45ac-bbdd-0069413f6b3a	New consultation request	A customer has requested a live video consultation with you.	{"type": "consultation_request", "consultation_id": "f406d5a0-939b-45df-b4a5-cb099d5420b7"}	f	f	2026-08-29 07:22:26.818882+00
e10d9b26-c80b-4e59-afb3-71aa7272d0f7	8ce31a51-34d2-45ac-bbdd-0069413f6b3a	New consultation request	A customer has requested a live video consultation with you.	{"type": "consultation_request", "consultation_id": "2036db4d-cdd6-4986-9bad-2ac482dad2c3"}	f	f	2026-08-29 07:22:53.264428+00
74729712-ec1e-45e7-be23-1bd3faf77dcc	aebfbed2-7205-437b-9045-65d1b0240e6a	Consultation accepted	A technician has accepted your live video consultation. Connecting now...	{"type": "consultation_accepted", "consultation_id": "2036db4d-cdd6-4986-9bad-2ac482dad2c3"}	f	f	2026-08-29 07:22:59.616956+00
e651512a-9ff8-4587-b826-c3ae320ecc4f	aebfbed2-7205-437b-9045-65d1b0240e6a	Payment successful	Your payment for booking has been received. Thank you!	{"type": "payment_success", "booking_id": "6159f686-4eca-4829-8984-8d748016d126", "payment_id": "89e44e59-cf5c-4a55-8e50-8b4d7c56aeec"}	f	f	2026-08-29 07:24:26.460395+00
670a8594-a16f-4622-9d53-10a007d5c691	3e09db72-8f82-49c5-81b4-b95be21ea46f	New consultation request	A customer has requested a live video consultation with you.	{"type": "consultation_request", "consultation_id": "bf67913f-43f9-4670-a4df-627a23439468"}	f	f	2026-08-29 07:50:31.019109+00
a9e1fb61-6c5e-4c79-aa35-c16a5520096b	3e09db72-8f82-49c5-81b4-b95be21ea46f	New consultation request	A customer has requested a live video consultation with you.	{"type": "consultation_request", "consultation_id": "e90fc5b4-f6b7-4048-8431-3eccf66fa7ce"}	f	f	2026-08-29 07:50:33.275479+00
a32d69f7-42fd-4f4d-a9cc-bc27badbb536	3e09db72-8f82-49c5-81b4-b95be21ea46f	New consultation request	A customer has requested a live video consultation with you.	{"type": "consultation_request", "consultation_id": "0c773879-f515-475d-b36e-71c90ce3d441"}	f	f	2026-08-29 07:50:56.978524+00
fa2fd543-7636-4d85-b20e-defcb053ce75	3e09db72-8f82-49c5-81b4-b95be21ea46f	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "cf08d139-b61e-40ba-b4ad-26c92233673a"}	f	f	2026-08-29 07:52:30.997475+00
55c08399-5619-4d2a-8e33-34f931e7f8fd	3e09db72-8f82-49c5-81b4-b95be21ea46f	New message	Hii	{"type": "booking_message", "booking_id": "cf08d139-b61e-40ba-b4ad-26c92233673a"}	f	f	2026-08-29 07:53:07.198216+00
60afaf17-1b50-4308-8c23-c2a3fe85b745	3e09db72-8f82-49c5-81b4-b95be21ea46f	New message	Pradnya	{"type": "booking_message", "booking_id": "cf08d139-b61e-40ba-b4ad-26c92233673a"}	f	f	2026-08-29 07:53:10.374686+00
495de9ac-f150-4132-8900-e78c91e25463	3e09db72-8f82-49c5-81b4-b95be21ea46f	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "f4149c23-8927-400a-889e-5e8a466e38df"}	f	f	2026-08-29 08:05:33.876486+00
8ab8bb61-3653-450e-bf81-7be7268f2646	3e09db72-8f82-49c5-81b4-b95be21ea46f	New message	Helloo	{"type": "booking_message", "booking_id": "f4149c23-8927-400a-889e-5e8a466e38df"}	f	f	2026-08-29 08:05:56.706394+00
ea3ee89e-4223-4fb0-afa3-3e4d75410072	3e09db72-8f82-49c5-81b4-b95be21ea46f	New consultation request	A customer has requested a live video consultation with you.	{"type": "consultation_request", "consultation_id": "c8df6adb-01ef-4600-a9c9-bd8a80677375"}	f	f	2026-08-29 08:06:03.106473+00
26eae6ec-98dd-4ea4-8b64-972503a376a6	3e09db72-8f82-49c5-81b4-b95be21ea46f	New consultation request	A customer has requested a live video consultation with you.	{"type": "consultation_request", "consultation_id": "13cbf778-2d02-4ee9-97c0-1661b8c9094a"}	f	f	2026-08-29 08:09:35.488607+00
3edf163c-c27c-47f3-8348-bde850308eb6	a5bcbdcb-965d-4e7e-843b-7e16cfd43eb4	New consultation request	A customer has requested a live video consultation with you.	{"type": "consultation_request", "consultation_id": "3f4fa8b4-e396-4f38-89f9-ccc4ff06bdcf"}	f	f	2026-08-29 08:11:11.405228+00
07ed9f5d-2555-4d5b-a441-e4d273ac9b3c	5978c7ed-c201-40f9-ac16-08fcb5d81431	Consultation accepted	A technician has accepted your live video consultation. Connecting now...	{"type": "consultation_accepted", "consultation_id": "3f4fa8b4-e396-4f38-89f9-ccc4ff06bdcf"}	f	f	2026-08-29 08:11:25.35682+00
b29b2245-a402-4641-9f37-103dd6a3d8ca	a5bcbdcb-965d-4e7e-843b-7e16cfd43eb4	New consultation request	A customer has requested a live video consultation with you.	{"type": "consultation_request", "consultation_id": "80b27655-eb13-42bd-bd43-69235b6a0aca"}	f	f	2026-08-29 08:12:35.457083+00
0f676cf0-d669-46ac-a36e-4181b6f207f4	5978c7ed-c201-40f9-ac16-08fcb5d81431	Consultation accepted	A technician has accepted your live video consultation. Connecting now...	{"type": "consultation_accepted", "consultation_id": "80b27655-eb13-42bd-bd43-69235b6a0aca"}	f	f	2026-08-29 08:13:09.893372+00
4d918a6e-64c5-4b05-93f0-5f14aa485bf4	3e09db72-8f82-49c5-81b4-b95be21ea46f	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "9db1257c-e883-4d18-b922-5e88d366e304"}	f	f	2026-08-29 08:34:40.532476+00
f75c03eb-8069-4717-8dd1-7d3292516295	3e09db72-8f82-49c5-81b4-b95be21ea46f	New message	Hii8i	{"type": "booking_message", "booking_id": "9db1257c-e883-4d18-b922-5e88d366e304"}	f	f	2026-08-29 08:34:49.785976+00
b1889988-49f8-4e42-9b1d-5be87b1f8e10	a5bcbdcb-965d-4e7e-843b-7e16cfd43eb4	New consultation request	A customer has requested a live video consultation with you.	{"type": "consultation_request", "consultation_id": "7e4e3641-1cd1-407e-8468-5f1e68f37241"}	f	f	2026-08-29 08:40:21.265914+00
9220bf4e-26c4-4067-b8e1-3327030d56f6	a5bcbdcb-965d-4e7e-843b-7e16cfd43eb4	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "b5812643-16d6-4b05-b6d8-e8f14a9d8b29"}	f	f	2026-08-29 08:41:53.251258+00
3a2b4687-2e65-4161-a98b-c224d93c102b	a5bcbdcb-965d-4e7e-843b-7e16cfd43eb4	New message	Heyyy	{"type": "booking_message", "booking_id": "b5812643-16d6-4b05-b6d8-e8f14a9d8b29"}	f	f	2026-08-29 08:42:03.513335+00
2247d23a-47b6-4963-8cba-b9caf07d9d55	3e09db72-8f82-49c5-81b4-b95be21ea46f	New consultation request	A customer has requested a live video consultation with you.	{"type": "consultation_request", "consultation_id": "9b61cba5-8cda-4e47-977f-d24c2c00651b"}	f	f	2026-08-29 08:47:11.880709+00
adfa02cc-3a48-4a94-a062-97d05a682aab	3e09db72-8f82-49c5-81b4-b95be21ea46f	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "26823039-9062-4987-97a8-06b71e66f580"}	f	f	2026-08-29 08:48:20.586063+00
862cfb69-3d01-4e0c-a7d8-f8bb2e91e3ce	4f3d12f3-d8a6-4c97-8016-2d44b252426f	Booking update	Your booking status changed to in_progress	{"type": "booking_status", "booking_id": "b5812643-16d6-4b05-b6d8-e8f14a9d8b29"}	f	f	2026-08-29 09:00:06.83467+00
f5d15f70-0fff-4216-b5a1-ab0023b2041e	4f3d12f3-d8a6-4c97-8016-2d44b252426f	Invoice ready	Your technician has completed the job. Amount due: ₹199.00. Tap to pay.	{"type": "invoice_ready", "booking_id": "b5812643-16d6-4b05-b6d8-e8f14a9d8b29", "final_price": "199.00"}	f	f	2026-08-29 09:05:18.330255+00
dae03e4e-a502-4223-b4d3-773c387a76cc	4f3d12f3-d8a6-4c97-8016-2d44b252426f	New message	Heyy	{"type": "booking_message", "booking_id": "b5812643-16d6-4b05-b6d8-e8f14a9d8b29"}	f	f	2026-08-29 09:30:59.193987+00
1bfbf598-b96a-4d7e-926b-3231c676ef04	8ce31a51-34d2-45ac-bbdd-0069413f6b3a	New consultation request	A customer has requested a live video consultation with you.	{"type": "consultation_request", "consultation_id": "f2469e92-31c7-49fa-8f51-48dc12fb4146"}	f	f	2026-08-29 10:59:40.180506+00
4dac54b5-41fd-4662-875b-619b5838491b	aebfbed2-7205-437b-9045-65d1b0240e6a	Consultation accepted	A technician has accepted your live video consultation. Connecting now...	{"type": "consultation_accepted", "consultation_id": "f2469e92-31c7-49fa-8f51-48dc12fb4146"}	f	f	2026-08-29 10:59:48.783283+00
416a661e-de42-4554-bbb5-2c93658d6a57	8ce31a51-34d2-45ac-bbdd-0069413f6b3a	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "08c5ea8e-e260-4e2d-b604-be16d8092334"}	f	f	2026-08-29 11:00:18.287281+00
08584ea1-8cc3-4eef-85f0-bf8e83f9d538	8ce31a51-34d2-45ac-bbdd-0069413f6b3a	New consultation request	A customer has requested a live video consultation with you.	{"type": "consultation_request", "consultation_id": "39277fea-09d8-4c3c-b033-96095b7ffed5"}	f	f	2026-08-29 11:03:54.875596+00
56a66c79-c31f-4001-a2f0-69d76baf0618	3e09db72-8f82-49c5-81b4-b95be21ea46f	New consultation request	A customer is requesting a live video consultation.	{"type": "consultation_request", "consultation_id": "0029ec35-42ce-4e16-929f-5b35b8f7dad6"}	f	f	2026-08-29 17:55:31.371987+00
c51c4765-8b19-44cb-84fc-fa6d60f8c830	a5bcbdcb-965d-4e7e-843b-7e16cfd43eb4	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "dad82ade-9ea9-4256-9005-988faba26cba"}	f	f	2026-08-30 01:09:29.104595+00
4e87380b-c391-4d5c-a8b5-38b8159248a5	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to on_the_way	{"type": "booking_status", "booking_id": "dad82ade-9ea9-4256-9005-988faba26cba"}	f	f	2026-08-30 02:27:46.07046+00
113211fb-86ee-403d-b879-39592ac5e29e	8ce31a51-34d2-45ac-bbdd-0069413f6b3a	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "aca4efb5-c668-448f-8330-f4b71ae2238c"}	f	f	2026-08-30 02:47:22.503402+00
272e0582-1642-4ae2-aa3b-d75223b29125	8ce31a51-34d2-45ac-bbdd-0069413f6b3a	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "af6067b5-d9ef-4ffe-9a18-bbe5f2589f32"}	f	f	2026-08-30 02:47:59.92525+00
49547dc3-bac2-4e62-a28d-505be3c9d804	8ce31a51-34d2-45ac-bbdd-0069413f6b3a	New consultation request	A customer has requested a live video consultation with you.	{"type": "consultation_request", "consultation_id": "8f26d87e-7dd5-4170-8a70-225a8e52a3df"}	f	f	2026-08-30 02:48:14.293201+00
4dc05b3d-f009-472b-be68-08b70e62c0f4	8ce31a51-34d2-45ac-bbdd-0069413f6b3a	New consultation request	A customer has requested a live video consultation with you.	{"type": "consultation_request", "consultation_id": "c11573ec-d50d-4259-b19b-c71b5934c4bc"}	f	f	2026-08-30 03:22:16.989488+00
816278f0-5188-464b-9115-196adb2d1ba9	a5bcbdcb-965d-4e7e-843b-7e16cfd43eb4	New consultation request	A customer is requesting a live video consultation.	{"type": "consultation_request", "consultation_id": "f0199c14-07f8-46ae-8ab5-549e5134e874"}	f	f	2026-08-30 03:22:49.383048+00
606795d6-98ec-40b3-b291-d11c6c5e0aca	8ce31a51-34d2-45ac-bbdd-0069413f6b3a	New consultation request	A customer has requested a live video consultation with you.	{"type": "consultation_request", "consultation_id": "1ef4c97c-2aaa-408a-bf87-d33cddcd12d2"}	f	f	2026-08-30 18:08:58.321852+00
ea3c045b-0644-40c5-bf88-8f5c6165c9b5	8ce31a51-34d2-45ac-bbdd-0069413f6b3a	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "ee0f264e-3679-4ff8-8c85-0e75b8793e14"}	f	f	2026-08-30 18:09:19.295549+00
e48c58ee-93b4-4401-9582-4c40863879b8	3e09db72-8f82-49c5-81b4-b95be21ea46f	New consultation request	A customer has requested a live video consultation with you.	{"type": "consultation_request", "consultation_id": "b94b408d-85c4-4951-b1f3-8882b9131014"}	f	f	2026-08-30 18:15:39.240918+00
cd92c7d3-46a1-4795-95f3-6a0e01f9fd33	a5bcbdcb-965d-4e7e-843b-7e16cfd43eb4	New consultation request	A customer has requested a live video consultation with you.	{"type": "consultation_request", "consultation_id": "42b04f77-9ac1-4e3b-badd-37be365c30a2"}	f	f	2026-08-30 18:16:03.506194+00
bb9008b2-57ac-4330-bcb7-9f3c99b674fe	a5bcbdcb-965d-4e7e-843b-7e16cfd43eb4	New consultation request	A customer has requested a live video consultation with you.	{"type": "consultation_request", "consultation_id": "7d07fa54-0cb3-4d1a-bfb1-602155c1710b"}	f	f	2026-08-30 18:16:31.701574+00
f2fcc3d7-bdf6-467c-befb-58a33c1c2b45	aebfbed2-7205-437b-9045-65d1b0240e6a	Consultation accepted	A technician has accepted your live video consultation. Connecting now...	{"type": "consultation_accepted", "consultation_id": "7d07fa54-0cb3-4d1a-bfb1-602155c1710b"}	f	f	2026-08-30 18:16:40.56031+00
f3a095ed-da78-48b2-b709-5e0cf9a3776e	a5bcbdcb-965d-4e7e-843b-7e16cfd43eb4	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "68bc8edb-976c-4030-bc76-89486f0ea45c"}	f	f	2026-08-30 18:17:25.362236+00
0ac14db2-0095-467f-b382-6ef54be8fed3	a5bcbdcb-965d-4e7e-843b-7e16cfd43eb4	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "fd7da0bc-0c12-4140-b6fa-b74bbd7e714c"}	f	f	2026-08-30 18:18:33.164558+00
1a4e3c2e-4c56-4e53-9117-1a297422934b	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to on_the_way	{"type": "booking_status", "booking_id": "fd7da0bc-0c12-4140-b6fa-b74bbd7e714c"}	f	f	2026-08-30 18:18:49.843232+00
23c6a554-d7ee-4187-977f-bdc0f542449c	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to on_the_way	{"type": "booking_status", "booking_id": "68bc8edb-976c-4030-bc76-89486f0ea45c"}	f	f	2026-08-30 18:19:26.486337+00
583f5615-4102-41b0-b14a-e152d5c38763	a5bcbdcb-965d-4e7e-843b-7e16cfd43eb4	New message	Hiii	{"type": "booking_message", "booking_id": "dad82ade-9ea9-4256-9005-988faba26cba"}	f	f	2026-08-30 18:20:03.132554+00
cb3426c0-6674-4f28-8875-0f6cce0699b8	aebfbed2-7205-437b-9045-65d1b0240e6a	New message	Hii	{"type": "booking_message", "booking_id": "fd7da0bc-0c12-4140-b6fa-b74bbd7e714c"}	f	f	2026-08-30 18:20:33.30185+00
4a8b998e-ed98-4f64-99ba-492ddba3a590	aebfbed2-7205-437b-9045-65d1b0240e6a	New message	Hii	{"type": "booking_message", "booking_id": "fd7da0bc-0c12-4140-b6fa-b74bbd7e714c"}	f	f	2026-08-30 18:20:58.086888+00
aeabadb9-04c4-4f62-a93a-d902a7e9398f	a5bcbdcb-965d-4e7e-843b-7e16cfd43eb4	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "144a9b77-35dd-48ca-ac63-d4fa3c2b8d1a"}	f	f	2026-08-31 03:02:58.266672+00
aaebebaa-04e8-413e-beb7-c2088d395fee	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to on_the_way	{"type": "booking_status", "booking_id": "144a9b77-35dd-48ca-ac63-d4fa3c2b8d1a"}	f	f	2026-08-31 03:03:11.490523+00
7920e560-5533-4450-8c91-ae4fb98717b7	a5bcbdcb-965d-4e7e-843b-7e16cfd43eb4	New message	Hiii	{"type": "booking_message", "booking_id": "144a9b77-35dd-48ca-ac63-d4fa3c2b8d1a"}	f	f	2026-08-31 03:03:56.608006+00
3b54292a-13b8-4eef-9e8d-a22e43df4176	3e09db72-8f82-49c5-81b4-b95be21ea46f	New consultation request	A customer is requesting a live video consultation.	{"type": "consultation_request", "consultation_id": "3a14e134-43bf-4adc-8772-45446ca5cb0f"}	f	f	2026-08-31 03:10:46.266687+00
1b0e94b7-7042-4cfd-8dfb-ba9febe2e4c3	3e09db72-8f82-49c5-81b4-b95be21ea46f	New consultation request	A customer is requesting a live video consultation.	{"type": "consultation_request", "consultation_id": "13ae1d53-e0ad-456c-ad56-12831b099445"}	f	f	2026-08-31 03:55:56.384732+00
5266a9da-a347-4c37-bf60-f22b066a83ca	a5bcbdcb-965d-4e7e-843b-7e16cfd43eb4	New consultation request	A customer has requested a live video consultation with you.	{"type": "consultation_request", "consultation_id": "fb2a6026-2ab4-467b-bbed-8fdd7ee42172"}	f	f	2026-08-31 04:20:06.672423+00
80f2b08f-f2aa-4e7a-83fe-d51659f4a0f2	a5bcbdcb-965d-4e7e-843b-7e16cfd43eb4	New consultation request	A customer has requested a live video consultation with you.	{"type": "consultation_request", "consultation_id": "95151443-417a-40ee-b10e-e8f3c0908a31"}	f	f	2026-08-31 04:35:54.459839+00
b6ac89b5-cb93-4bde-baaa-84c6db3f8b2b	a5bcbdcb-965d-4e7e-843b-7e16cfd43eb4	New consultation request	A customer has requested a live video consultation with you.	{"type": "consultation_request", "consultation_id": "559f6231-67d3-4f15-91ce-f66db43600fa"}	f	f	2026-08-31 04:39:47.397244+00
d49e035f-559c-4640-9307-dfac310920e1	a5bcbdcb-965d-4e7e-843b-7e16cfd43eb4	New consultation request	A customer has requested a live video consultation with you.	{"type": "consultation_request", "consultation_id": "468c9dcb-6560-4575-9aae-916a81f4ef6d"}	f	f	2026-08-31 04:44:30.134856+00
e24c6333-7239-40f0-a421-f4fb70a06da8	a5bcbdcb-965d-4e7e-843b-7e16cfd43eb4	New consultation request	A customer has requested a live video consultation with you.	{"type": "consultation_request", "consultation_id": "c288da0a-2893-43d9-9837-2a512078caf3"}	f	f	2026-08-31 04:53:12.158879+00
b43e4838-b4ca-4561-b2d1-bea7a5f42c75	a5bcbdcb-965d-4e7e-843b-7e16cfd43eb4	New consultation request	A customer has requested a live video consultation with you.	{"type": "consultation_request", "consultation_id": "0abd7750-b49c-47e6-aa38-2678caab7813"}	f	f	2026-08-31 04:55:55.805085+00
b7418a14-d820-4f76-a47b-094ed92a4451	a5bcbdcb-965d-4e7e-843b-7e16cfd43eb4	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "74bbd88d-6558-400a-be33-5babcc7a841b"}	f	f	2026-08-31 04:57:25.905529+00
289b4c54-f487-409d-9ed8-a64245b1e9be	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to on_the_way	{"type": "booking_status", "booking_id": "74bbd88d-6558-400a-be33-5babcc7a841b"}	f	f	2026-08-31 04:57:32.963467+00
170fb4b3-d500-4ab4-877a-92ac859101d5	8ce31a51-34d2-45ac-bbdd-0069413f6b3a	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "9ecf2820-25fb-46c3-9429-8ba10e59398e"}	f	f	2026-08-31 05:08:00.412719+00
3086dfb5-6648-4483-acbb-d8e301395b96	a5bcbdcb-965d-4e7e-843b-7e16cfd43eb4	New consultation request	A customer has requested a live video consultation with you.	{"type": "consultation_request", "consultation_id": "0c027092-7a03-4847-a74a-c6067ff5d428"}	f	f	2026-08-31 05:22:28.201269+00
656891a0-797e-488c-a437-1551e0c5fca1	a5bcbdcb-965d-4e7e-843b-7e16cfd43eb4	New consultation request	A customer has requested a live video consultation with you.	{"type": "consultation_request", "consultation_id": "c454e826-959d-4f3c-874c-079e437ef12c"}	f	f	2026-08-31 05:23:56.866794+00
b63d7053-beb0-48a3-b772-c321717e12db	aebfbed2-7205-437b-9045-65d1b0240e6a	Call not answered	The technician couldn't take your live video consultation right now.	{"type": "consultation_rejected", "consultation_id": "0c027092-7a03-4847-a74a-c6067ff5d428"}	f	f	2026-08-31 05:25:08.860964+00
998fd35c-873c-46fd-8fc7-4e40f6da0997	a5bcbdcb-965d-4e7e-843b-7e16cfd43eb4	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "97804867-d6df-4dcb-9ab4-458d025d57b0"}	f	f	2026-08-31 05:30:56.974625+00
b33169b3-cbf6-445b-bbc9-8e161f38e519	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to on_the_way	{"type": "booking_status", "booking_id": "97804867-d6df-4dcb-9ab4-458d025d57b0"}	f	f	2026-08-31 05:31:18.002197+00
ee575c29-fc82-481b-a39a-d98d98f904e5	a5bcbdcb-965d-4e7e-843b-7e16cfd43eb4	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "57538146-3db7-4baa-b383-090b36ab505e"}	f	f	2026-08-31 05:32:27.033196+00
38f3dfb7-ba55-479f-912f-b199bdf2a939	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to on_the_way	{"type": "booking_status", "booking_id": "57538146-3db7-4baa-b383-090b36ab505e"}	f	f	2026-08-31 05:32:31.672176+00
019961e6-61d0-48df-8d3b-d8dd1e4ec62a	a5bcbdcb-965d-4e7e-843b-7e16cfd43eb4	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "0a5791e9-c5bc-42b4-96d0-530df2bc92b1"}	f	f	2026-08-31 05:39:14.681147+00
f6aef5fa-690a-4697-bc76-09fcecebec77	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to on_the_way	{"type": "booking_status", "booking_id": "0a5791e9-c5bc-42b4-96d0-530df2bc92b1"}	f	f	2026-08-31 05:39:19.792481+00
b742a1e5-8405-4213-bad7-ff5381e948cd	a5bcbdcb-965d-4e7e-843b-7e16cfd43eb4	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "8bf61946-c99c-4096-a1f4-4f7184b454eb"}	f	f	2026-08-31 05:51:41.429027+00
f1a0b611-325a-4c76-95e5-876e628ce646	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to on_the_way	{"type": "booking_status", "booking_id": "8bf61946-c99c-4096-a1f4-4f7184b454eb"}	f	f	2026-08-31 05:51:51.293927+00
def98a97-afeb-4224-87f2-351957b557b3	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to arrived	{"type": "booking_status", "booking_id": "8bf61946-c99c-4096-a1f4-4f7184b454eb"}	f	f	2026-08-31 05:51:52.294772+00
07e64c4a-e33e-4ac2-b228-c5d45b8ff5c3	a5bcbdcb-965d-4e7e-843b-7e16cfd43eb4	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "bdd5c7c5-4dff-49ba-85ab-25045ee16276"}	f	f	2026-08-31 06:07:21.074423+00
9b52a45b-7a00-4957-a352-60b88462de9a	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to on_the_way	{"type": "booking_status", "booking_id": "bdd5c7c5-4dff-49ba-85ab-25045ee16276"}	f	f	2026-08-31 06:07:26.428072+00
5e6bf786-d6bf-4a1d-b158-01741d41e80f	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to arrived	{"type": "booking_status", "booking_id": "bdd5c7c5-4dff-49ba-85ab-25045ee16276"}	f	f	2026-08-31 06:07:29.097221+00
78359c0c-e3d6-4555-9978-5047b11314e2	a5bcbdcb-965d-4e7e-843b-7e16cfd43eb4	New consultation request	A customer has requested a live video consultation with you.	{"type": "consultation_request", "consultation_id": "63a8a962-1979-4f36-be10-3bc2233275bd"}	f	f	2026-08-31 06:22:12.616123+00
d5eb0e3e-90ad-44d7-8c3f-27c5bbcafc35	a5bcbdcb-965d-4e7e-843b-7e16cfd43eb4	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "f6d1c69c-8a4a-4a40-af39-4217a4c404b8"}	f	f	2026-08-31 06:22:16.925158+00
4085f814-04e9-4d95-90a1-85a06caa4d8d	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to on_the_way	{"type": "booking_status", "booking_id": "f6d1c69c-8a4a-4a40-af39-4217a4c404b8"}	f	f	2026-08-31 06:22:21.405106+00
6f493baf-76a3-4202-bbbb-305331bb1f84	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to arrived	{"type": "booking_status", "booking_id": "f6d1c69c-8a4a-4a40-af39-4217a4c404b8"}	f	f	2026-08-31 06:22:22.24224+00
d8fb540f-e99c-466b-af9f-530249000d78	a5bcbdcb-965d-4e7e-843b-7e16cfd43eb4	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "98b8c4e5-0939-44ee-a66e-8c069d3f110a"}	f	f	2026-08-31 06:26:59.202149+00
27fd9582-2b10-40c0-adca-8d846ed3efa8	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to on_the_way	{"type": "booking_status", "booking_id": "98b8c4e5-0939-44ee-a66e-8c069d3f110a"}	f	f	2026-08-31 06:27:04.578528+00
5e9206b6-d215-443f-82c1-845d018bf178	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to arrived	{"type": "booking_status", "booking_id": "98b8c4e5-0939-44ee-a66e-8c069d3f110a"}	f	f	2026-08-31 06:27:06.733139+00
456ac941-39e7-4ab3-83d4-1478b35cb336	a5bcbdcb-965d-4e7e-843b-7e16cfd43eb4	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "61e186b5-63fa-457a-a56c-3789f77e8e79"}	f	f	2026-08-31 06:29:31.050567+00
9407f475-6b1d-4837-b7aa-fc67c6d77d83	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to on_the_way	{"type": "booking_status", "booking_id": "61e186b5-63fa-457a-a56c-3789f77e8e79"}	f	f	2026-08-31 06:29:37.231841+00
7d1d4a48-e55a-40e0-88b8-d3d33137fa7a	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to arrived	{"type": "booking_status", "booking_id": "61e186b5-63fa-457a-a56c-3789f77e8e79"}	f	f	2026-08-31 06:29:40.285404+00
c6b2274d-593c-4989-8e83-e85918b56230	a5bcbdcb-965d-4e7e-843b-7e16cfd43eb4	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "38839d69-9794-4989-95a0-2fb767af3575"}	f	f	2026-08-31 06:42:33.445612+00
3057f041-1ea2-4d6f-af0c-e6f45a0cb45c	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to on_the_way	{"type": "booking_status", "booking_id": "38839d69-9794-4989-95a0-2fb767af3575"}	f	f	2026-08-31 06:42:38.262165+00
25873ed9-49a4-4d37-9cf9-1f9a286ba2f8	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to arrived	{"type": "booking_status", "booking_id": "38839d69-9794-4989-95a0-2fb767af3575"}	f	f	2026-08-31 06:42:39.098972+00
7a33cfe3-0d59-4149-9526-2f24daa4bd6c	a5bcbdcb-965d-4e7e-843b-7e16cfd43eb4	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "341036e8-d595-4979-b2f5-346bc5f02962"}	f	f	2026-08-31 06:52:54.184556+00
cd929a13-e842-4d95-ab04-b69efca99b6e	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to on_the_way	{"type": "booking_status", "booking_id": "341036e8-d595-4979-b2f5-346bc5f02962"}	f	f	2026-08-31 06:52:57.90594+00
e400e2a9-912d-495d-a7a5-d446690605c7	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to arrived	{"type": "booking_status", "booking_id": "341036e8-d595-4979-b2f5-346bc5f02962"}	f	f	2026-08-31 06:52:59.477284+00
7e3dd6d5-a148-4084-b7b0-9203eec360c0	a5bcbdcb-965d-4e7e-843b-7e16cfd43eb4	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "a7a39d1e-27f4-4855-9a21-3132d0dbbddc"}	f	f	2026-08-31 06:55:09.094146+00
00ddec5b-95ad-4413-833a-676238edb239	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to on_the_way	{"type": "booking_status", "booking_id": "a7a39d1e-27f4-4855-9a21-3132d0dbbddc"}	f	f	2026-08-31 06:55:13.566479+00
56719a79-e7f6-4466-8c48-31b969fb6002	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to arrived	{"type": "booking_status", "booking_id": "a7a39d1e-27f4-4855-9a21-3132d0dbbddc"}	f	f	2026-08-31 06:55:14.862073+00
fc0e8ed2-7cd6-410e-b689-4326b5342527	35bb12a9-b2c6-4f77-b383-307759714318	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "ebfcf350-dcd8-498d-b0c7-bab5ea2b6408"}	f	f	2026-08-31 06:59:27.628897+00
01963afa-2f3c-412f-8870-c1ff9aae37a7	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to on_the_way	{"type": "booking_status", "booking_id": "ebfcf350-dcd8-498d-b0c7-bab5ea2b6408"}	f	f	2026-08-31 06:59:34.114928+00
d251faeb-b197-44e6-b105-31f2ea1dcdc5	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to arrived	{"type": "booking_status", "booking_id": "ebfcf350-dcd8-498d-b0c7-bab5ea2b6408"}	f	f	2026-08-31 06:59:34.944164+00
5d0eb4fb-1e3e-4047-a88a-7b28c9ed6ebf	35bb12a9-b2c6-4f77-b383-307759714318	New consultation request	A customer has requested a live video consultation with you.	{"type": "consultation_request", "consultation_id": "afe18add-0154-4533-9029-11dd434cc1d3"}	f	f	2026-08-31 07:57:44.456149+00
de8d3fb1-8270-49c6-bfd6-ec333dbd75ff	aebfbed2-7205-437b-9045-65d1b0240e6a	Consultation accepted	A technician has accepted your live video consultation. Connecting now...	{"type": "consultation_accepted", "consultation_id": "afe18add-0154-4533-9029-11dd434cc1d3"}	f	f	2026-08-31 07:58:51.603048+00
3c332e52-4605-4352-a454-d8dcd90c2d26	35bb12a9-b2c6-4f77-b383-307759714318	New consultation request	A customer has requested a live video consultation with you.	{"type": "consultation_request", "consultation_id": "c21c3e19-f8f0-4a12-a18a-41a3fdc3107b"}	f	f	2026-08-31 08:49:42.515449+00
576e65ff-5ec2-4f8d-85f2-073482e103c1	aebfbed2-7205-437b-9045-65d1b0240e6a	Consultation accepted	A technician has accepted your live video consultation. Connecting now...	{"type": "consultation_accepted", "consultation_id": "c21c3e19-f8f0-4a12-a18a-41a3fdc3107b"}	f	f	2026-08-31 08:51:58.139585+00
1fc53b42-84ca-42e3-b56a-a210d2e003bf	35bb12a9-b2c6-4f77-b383-307759714318	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "271820c9-e8ee-4424-abfc-ffb4ab065c02"}	f	f	2026-08-31 09:04:33.176016+00
407d0a6d-50ba-4536-90b4-b0ea834ff783	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to on_the_way	{"type": "booking_status", "booking_id": "271820c9-e8ee-4424-abfc-ffb4ab065c02"}	f	f	2026-08-31 09:04:41.389822+00
ba439138-72e6-4f4a-9a45-c51024850d89	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to arrived	{"type": "booking_status", "booking_id": "271820c9-e8ee-4424-abfc-ffb4ab065c02"}	f	f	2026-08-31 09:04:43.503912+00
e8504521-2eaf-4b56-ba47-f9c503abbdc1	35bb12a9-b2c6-4f77-b383-307759714318	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "56170d9e-66d0-4cf4-a346-eb76cec2856b"}	f	f	2026-08-31 09:05:25.510008+00
e9019064-2894-47cc-aa28-c8a8f6a8e2b5	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to on_the_way	{"type": "booking_status", "booking_id": "56170d9e-66d0-4cf4-a346-eb76cec2856b"}	f	f	2026-08-31 09:05:36.178457+00
2276f50e-58df-4370-a680-33c537636a1e	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to arrived	{"type": "booking_status", "booking_id": "56170d9e-66d0-4cf4-a346-eb76cec2856b"}	f	f	2026-08-31 09:05:36.975828+00
24c2ae46-8fb3-4b7e-a82b-d5f87e5dd44c	35bb12a9-b2c6-4f77-b383-307759714318	New message	Hiiii	{"type": "booking_message", "booking_id": "56170d9e-66d0-4cf4-a346-eb76cec2856b"}	f	f	2026-08-31 09:06:33.087176+00
6a41619f-b887-4320-b93a-354217ee6252	aebfbed2-7205-437b-9045-65d1b0240e6a	New message	Hello	{"type": "booking_message", "booking_id": "56170d9e-66d0-4cf4-a346-eb76cec2856b"}	f	f	2026-08-31 09:06:48.416021+00
1221c619-2a15-4a6a-bd5c-01093ccf15c5	35bb12a9-b2c6-4f77-b383-307759714318	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "9640544d-5c9f-4d3f-a1a4-ec751bd6e1bd"}	f	f	2026-08-31 17:26:30.060101+00
ea5e60a6-661c-41c6-ae86-223d5be8480b	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to on_the_way	{"type": "booking_status", "booking_id": "9640544d-5c9f-4d3f-a1a4-ec751bd6e1bd"}	f	f	2026-08-31 17:26:39.306642+00
a7e0c24d-835e-410c-a27f-f6d28537ce5e	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to arrived	{"type": "booking_status", "booking_id": "9640544d-5c9f-4d3f-a1a4-ec751bd6e1bd"}	f	f	2026-08-31 17:26:42.393541+00
3dc62824-a326-4508-931f-91fc087c3c1f	35bb12a9-b2c6-4f77-b383-307759714318	New message	Hiii	{"type": "booking_message", "booking_id": "9640544d-5c9f-4d3f-a1a4-ec751bd6e1bd"}	f	f	2026-08-31 17:38:16.885373+00
9bcc952a-1e99-4b31-ba74-34aa7fe7c8a5	35bb12a9-b2c6-4f77-b383-307759714318	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "1f64b5e0-817e-435b-b7f3-c2d8b1df47e7"}	f	f	2026-09-01 03:09:36.017964+00
b7b73ad5-fe61-4516-a1f4-ccb9c7141d13	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to on_the_way	{"type": "booking_status", "booking_id": "1f64b5e0-817e-435b-b7f3-c2d8b1df47e7"}	f	f	2026-09-01 03:09:42.374897+00
c179ab91-7f6d-4d68-b6f1-678fa6d5e59e	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to arrived	{"type": "booking_status", "booking_id": "1f64b5e0-817e-435b-b7f3-c2d8b1df47e7"}	f	f	2026-09-01 03:09:44.131973+00
921e682a-0726-42b9-b9cf-09364637698b	8ce31a51-34d2-45ac-bbdd-0069413f6b3a	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "86bea55f-a33f-4450-9cf6-23534d9976e5"}	f	f	2026-09-01 06:06:51.646481+00
62784eef-6727-4c04-8eb2-d516ee90dabd	35bb12a9-b2c6-4f77-b383-307759714318	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "94f58d5b-b308-4537-9d2b-6c444a60e310"}	f	f	2026-09-01 06:23:26.290461+00
c604b699-5c84-46da-ad12-8e2a4a899674	3be2026d-ea02-43f3-bc41-e0b3e9bb133c	Booking update	Your booking status changed to on_the_way	{"type": "booking_status", "booking_id": "94f58d5b-b308-4537-9d2b-6c444a60e310"}	f	f	2026-09-01 06:23:36.804345+00
56475e5a-b133-40c0-b6f4-7291a936fdc0	3be2026d-ea02-43f3-bc41-e0b3e9bb133c	Booking update	Your booking status changed to on_the_way	{"type": "booking_status", "booking_id": "94f58d5b-b308-4537-9d2b-6c444a60e310"}	f	f	2026-09-01 06:23:41.286523+00
63a2a608-711c-43c2-87ce-9448f8c6b50e	3be2026d-ea02-43f3-bc41-e0b3e9bb133c	Booking update	Your booking status changed to on_the_way	{"type": "booking_status", "booking_id": "94f58d5b-b308-4537-9d2b-6c444a60e310"}	f	f	2026-09-01 06:23:42.294849+00
e351ba8b-b15c-4ffd-9605-ecf7ad9bb399	3be2026d-ea02-43f3-bc41-e0b3e9bb133c	Booking update	Your booking status changed to on_the_way	{"type": "booking_status", "booking_id": "94f58d5b-b308-4537-9d2b-6c444a60e310"}	f	f	2026-09-01 06:23:42.894845+00
ea54bbfc-b4d0-40cd-84f1-cc632a7b7f65	3be2026d-ea02-43f3-bc41-e0b3e9bb133c	Booking update	Your booking status changed to on_the_way	{"type": "booking_status", "booking_id": "94f58d5b-b308-4537-9d2b-6c444a60e310"}	f	f	2026-09-01 06:23:43.375786+00
c66166ff-2c38-4e48-bcb9-959a3edfc367	3be2026d-ea02-43f3-bc41-e0b3e9bb133c	Booking update	Your booking status changed to arrived	{"type": "booking_status", "booking_id": "94f58d5b-b308-4537-9d2b-6c444a60e310"}	f	f	2026-09-01 06:23:45.807196+00
26975782-9328-4d31-b875-4df1e029ebe8	3e09db72-8f82-49c5-81b4-b95be21ea46f	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "dd974c8f-062c-47e0-9079-945a264c324e"}	f	f	2026-09-01 07:00:59.583722+00
eab84165-7695-4383-95d6-3abe4e185416	3e09db72-8f82-49c5-81b4-b95be21ea46f	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "f95e9d73-b233-4478-a084-8297a5a0b17d"}	f	f	2026-09-01 07:14:40.454749+00
7903659d-38b2-4229-a236-086872bb843b	a5bcbdcb-965d-4e7e-843b-7e16cfd43eb4	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "de9638e9-bfe9-471d-b91e-908706f4e6d1"}	f	f	2026-09-01 07:16:32.45103+00
808df22b-b685-41d4-8a15-ed44064dbcd4	a5bcbdcb-965d-4e7e-843b-7e16cfd43eb4	New consultation request	A customer is requesting a live video consultation.	{"type": "consultation_request", "consultation_id": "9947a7b6-d435-49a7-a56b-e09a4fa4b389"}	f	f	2026-09-01 08:05:31.566942+00
5c3ac57a-2522-4949-a6cb-01bcf8ab1e6f	35bb12a9-b2c6-4f77-b383-307759714318	New consultation request	A customer is requesting a live video consultation.	{"type": "consultation_request", "consultation_id": "e4ac66d3-28a0-441b-8d92-4df78f7da25c"}	f	f	2026-09-01 08:45:06.38852+00
37fe2384-4b34-473b-a06b-41987e33ad98	35bb12a9-b2c6-4f77-b383-307759714318	New consultation booking request	A customer wants to schedule a live video consultation with you at 2 Sep, 7:00 AM. Please confirm.	{"type": "consultation_scheduled_request", "consultation_id": "9bbacdaf-39a8-4e50-8d21-c5c0ff1b5ebd"}	f	f	2026-09-01 08:48:31.373598+00
7d4b632d-7d18-4cbd-ae18-eec26f3131f5	3e09db72-8f82-49c5-81b4-b95be21ea46f	New consultation request	A customer is requesting a live video consultation.	{"type": "consultation_request", "consultation_id": "ec84b5a0-f6f7-4608-9ee7-c9e2b30d3978"}	f	f	2026-09-01 08:57:43.817001+00
f3f5573e-c1d6-44ea-b4fb-c524a62e6c2a	35bb12a9-b2c6-4f77-b383-307759714318	New consultation request	A customer is requesting a live video consultation.	{"type": "consultation_request", "consultation_id": "ff45f98d-8a40-47b0-aa0a-536f15d87e42"}	f	f	2026-09-01 09:01:57.937742+00
f4b1f1d1-04b7-408a-9b3d-1dc272ac73dc	aebfbed2-7205-437b-9045-65d1b0240e6a	New message	Hii	{"type": "booking_message", "booking_id": "9640544d-5c9f-4d3f-a1a4-ec751bd6e1bd"}	t	f	2026-08-31 17:37:57.483253+00
cd72d3f9-8d13-432e-bc8a-582f1bef6bb0	aebfbed2-7205-437b-9045-65d1b0240e6a	Consultation accepted	A technician has accepted your live video consultation. Connecting now...	{"type": "consultation_accepted", "consultation_id": "ff45f98d-8a40-47b0-aa0a-536f15d87e42"}	t	f	2026-09-01 09:02:11.702159+00
6229fca6-474b-4b81-8b18-aafe8cd3476f	aebfbed2-7205-437b-9045-65d1b0240e6a	Technician's recommendation is ready	Your technician sent a recommendation after the call. Review it to book a visit.	{"type": "consultation_recommendation", "consultation_id": "e4ac66d3-28a0-441b-8d92-4df78f7da25c"}	t	t	2026-09-01 08:46:55.179122+00
30d4c7d2-6b98-42db-aa32-9d951e329276	3e09db72-8f82-49c5-81b4-b95be21ea46f	New consultation request	A customer is requesting a live video consultation.	{"type": "consultation_request", "consultation_id": "13b130a9-e40d-4385-a9c1-edd358e93160"}	f	f	2026-09-01 09:51:21.199492+00
142daebf-e9ca-410f-bbe7-441ab579507e	3e09db72-8f82-49c5-81b4-b95be21ea46f	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "d6919e1e-3713-4ba7-aa47-852d496da26a"}	f	f	2026-09-01 10:48:25.629033+00
31e56f81-ef1c-4535-9a43-155cf9a202ef	a5bcbdcb-965d-4e7e-843b-7e16cfd43eb4	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "45de7d89-bd38-40c8-8735-f99d6c67a674"}	f	f	2026-09-01 10:59:12.233905+00
ad0680a3-4f8e-4279-877f-c0dfa4035707	064fad8e-000a-4ed1-a447-160afea13815	Booking update	Your booking status changed to on_the_way	{"type": "booking_status", "booking_id": "45de7d89-bd38-40c8-8735-f99d6c67a674"}	f	f	2026-09-01 10:59:17.831213+00
501d1b67-b170-4a1e-b54c-479da3ffa06b	064fad8e-000a-4ed1-a447-160afea13815	Booking update	Your booking status changed to arrived	{"type": "booking_status", "booking_id": "45de7d89-bd38-40c8-8735-f99d6c67a674"}	f	f	2026-09-01 10:59:19.538211+00
f867553a-c227-4b56-88ae-e66d31234ada	8ce31a51-34d2-45ac-bbdd-0069413f6b3a	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "edf7d099-aeb6-4acf-9e19-fad995abfb96"}	f	f	2026-09-01 11:22:59.374459+00
4948ffa4-ff14-443d-a9f4-5bad3eb1846c	a5bcbdcb-965d-4e7e-843b-7e16cfd43eb4	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "a0346c66-f6c1-466e-8f6d-4fd61c501153"}	f	f	2026-09-01 11:23:41.769085+00
eecda903-2acc-405f-b811-26f6735cd49b	064fad8e-000a-4ed1-a447-160afea13815	Booking update	Your booking status changed to arrived	{"type": "booking_status", "booking_id": "a0346c66-f6c1-466e-8f6d-4fd61c501153"}	f	f	2026-09-01 11:23:46.669551+00
cc1ebf20-e5cb-47ea-873d-cc431576a7b6	064fad8e-000a-4ed1-a447-160afea13815	Booking update	Your booking status changed to on_the_way	{"type": "booking_status", "booking_id": "a0346c66-f6c1-466e-8f6d-4fd61c501153"}	t	f	2026-09-01 11:23:45.925058+00
558e853f-d287-4bf1-bd89-2a0fe854be61	3e09db72-8f82-49c5-81b4-b95be21ea46f	New consultation booking request	A customer wants to schedule a live video consultation with you at 1 Sep, 12:28 PM. Please confirm.	{"type": "consultation_scheduled_request", "consultation_id": "d711424a-e678-452b-b47e-a9d504208158"}	f	f	2026-09-01 11:28:40.1321+00
549cd414-df23-481b-b608-3ce83bcb705a	064fad8e-000a-4ed1-a447-160afea13815	New message	Hello	{"type": "booking_message", "booking_id": "a0346c66-f6c1-466e-8f6d-4fd61c501153"}	f	f	2026-09-01 11:28:55.038458+00
80f205a0-2f77-4b57-8a68-22d756fc5e36	a5bcbdcb-965d-4e7e-843b-7e16cfd43eb4	New message	Hiiiiii	{"type": "booking_message", "booking_id": "a0346c66-f6c1-466e-8f6d-4fd61c501153"}	f	f	2026-09-01 11:29:10.829531+00
1fbd0995-5679-4751-a464-53d7ff2920ac	a5bcbdcb-965d-4e7e-843b-7e16cfd43eb4	New message	Hii	{"type": "booking_message", "booking_id": "a0346c66-f6c1-466e-8f6d-4fd61c501153"}	f	f	2026-09-01 11:29:13.496676+00
1b9445eb-c2cc-4f07-be16-2d3ccdfcfd25	064fad8e-000a-4ed1-a447-160afea13815	New message	Yup	{"type": "booking_message", "booking_id": "a0346c66-f6c1-466e-8f6d-4fd61c501153"}	f	f	2026-09-01 11:29:20.981099+00
c89f7635-8a66-4580-a696-1b5e9a8629e6	8ce31a51-34d2-45ac-bbdd-0069413f6b3a	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "ad934dd3-d075-4515-8acf-92c82c2b0e6d"}	f	f	2026-09-02 04:47:07.697498+00
10f03c39-82d0-48df-9a22-5fdc3f650fb2	8ce31a51-34d2-45ac-bbdd-0069413f6b3a	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "b16efaa0-4d95-4044-b794-62e407559ac6"}	f	f	2026-09-02 04:47:32.11398+00
e3ca8a4e-3368-440b-9b87-013f173bcaa2	8ce31a51-34d2-45ac-bbdd-0069413f6b3a	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "92ebb125-533e-4092-a72f-3d7d1a850b72"}	f	f	2026-09-02 04:52:52.142842+00
2da25ac9-3e09-4428-b622-807ef550e427	8ce31a51-34d2-45ac-bbdd-0069413f6b3a	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "3e55eab3-e739-46dd-94aa-48293f7b4663"}	f	f	2026-09-02 07:01:30.563381+00
8399eb3b-733b-4225-a82b-66dd768877bb	a5bcbdcb-965d-4e7e-843b-7e16cfd43eb4	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "ed453b6d-8abd-4ece-b23d-4964ddc56002"}	f	f	2026-09-02 07:01:48.587778+00
1efb0e1a-a8da-4633-9b22-173b4b819b73	35bb12a9-b2c6-4f77-b383-307759714318	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "069a4e97-aefb-4cc4-bfb0-ac69d75c7017"}	f	f	2026-09-02 07:48:50.756022+00
9fafaf7b-6ba1-4314-b50a-8ba5b4a3b103	aebfbed2-7205-437b-9045-65d1b0240e6a	Consultation accepted	A technician has accepted your live video consultation. Connecting now...	{"type": "consultation_accepted", "consultation_id": "e4ac66d3-28a0-441b-8d92-4df78f7da25c"}	t	t	2026-09-01 08:45:10.092469+00
db93f65c-f6c6-4e20-8007-d485cc894a14	35bb12a9-b2c6-4f77-b383-307759714318	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "4a1cca6f-0c29-45a4-86fd-c6da18db7024"}	f	f	2026-09-02 07:53:14.581472+00
53845218-404a-4490-b224-f4f62ec9a974	35bb12a9-b2c6-4f77-b383-307759714318	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "21c4ac3b-8dd8-41fa-95a9-acf978333671"}	f	f	2026-09-02 09:09:39.249019+00
f0dd5c65-4666-4b17-a069-f9ca021759e3	35bb12a9-b2c6-4f77-b383-307759714318	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "4e3bf9f3-2f68-4892-a9d5-444ae1e3f388"}	f	f	2026-09-03 03:13:01.984652+00
f997d960-733a-4d9b-8089-8efcc24fb532	3be2026d-ea02-43f3-bc41-e0b3e9bb133c	Booking update	Your booking status changed to on_the_way	{"type": "booking_status", "booking_id": "4e3bf9f3-2f68-4892-a9d5-444ae1e3f388"}	f	f	2026-09-03 03:13:06.376293+00
2dee2581-9db0-480a-976c-336770c0a700	3be2026d-ea02-43f3-bc41-e0b3e9bb133c	Booking update	Your booking status changed to arrived	{"type": "booking_status", "booking_id": "4e3bf9f3-2f68-4892-a9d5-444ae1e3f388"}	f	f	2026-09-03 03:13:08.780536+00
c1a62882-e24d-45a3-b5c8-cd57a19d641f	35bb12a9-b2c6-4f77-b383-307759714318	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "fb01b515-45a9-48ae-8126-9ff7044ebe64"}	f	f	2026-09-03 03:15:01.074268+00
04646dfe-ee86-4366-bb3e-3ac9cb1cd919	3be2026d-ea02-43f3-bc41-e0b3e9bb133c	Booking update	Your booking status changed to on_the_way	{"type": "booking_status", "booking_id": "fb01b515-45a9-48ae-8126-9ff7044ebe64"}	f	f	2026-09-03 03:15:07.002459+00
038d7042-8d13-45d7-9151-17e04691885d	3be2026d-ea02-43f3-bc41-e0b3e9bb133c	Booking update	Your booking status changed to arrived	{"type": "booking_status", "booking_id": "fb01b515-45a9-48ae-8126-9ff7044ebe64"}	f	f	2026-09-03 03:15:09.293195+00
57721ff0-be40-4f52-a97a-61f80c7d6002	35bb12a9-b2c6-4f77-b383-307759714318	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "de6289f8-f8c8-47c7-bfec-650c68178691"}	f	f	2026-09-03 03:15:26.68492+00
b7f24328-de45-434f-a0c4-aae9cfc57b31	3be2026d-ea02-43f3-bc41-e0b3e9bb133c	Booking update	Your booking status changed to on_the_way	{"type": "booking_status", "booking_id": "de6289f8-f8c8-47c7-bfec-650c68178691"}	f	f	2026-09-03 03:15:29.711729+00
8f9fbde9-4e2d-4091-8271-5b766e3001ff	35bb12a9-b2c6-4f77-b383-307759714318	New consultation request	A customer is requesting a live video consultation.	{"type": "consultation_request", "consultation_id": "98afd057-ed8a-4eec-9168-3c82c0dab672"}	f	f	2026-09-03 03:15:54.07753+00
19ed6fa7-e24b-40d0-bb78-85d9fb18d529	3be2026d-ea02-43f3-bc41-e0b3e9bb133c	Consultation accepted	A technician has accepted your live video consultation. Connecting now...	{"type": "consultation_accepted", "consultation_id": "98afd057-ed8a-4eec-9168-3c82c0dab672"}	f	f	2026-09-03 03:16:00.314632+00
b78eecfe-a5af-4ae7-b71c-2828f12e9bb5	35bb12a9-b2c6-4f77-b383-307759714318	New consultation request	A customer is requesting a live video consultation.	{"type": "consultation_request", "consultation_id": "6916eed6-597f-468d-bfcf-fc0f1ea783fd"}	f	f	2026-09-03 03:16:34.073462+00
a84d6ad3-35c0-492f-925b-9253c675e906	3be2026d-ea02-43f3-bc41-e0b3e9bb133c	Consultation accepted	A technician has accepted your live video consultation. Connecting now...	{"type": "consultation_accepted", "consultation_id": "6916eed6-597f-468d-bfcf-fc0f1ea783fd"}	f	f	2026-09-03 03:16:37.923538+00
3e71144d-2a3d-4f8a-8db2-441659a79396	3be2026d-ea02-43f3-bc41-e0b3e9bb133c	Technician's recommendation is ready	Your technician sent a recommendation after the call. Review it to book a visit.	{"type": "consultation_recommendation", "consultation_id": "6916eed6-597f-468d-bfcf-fc0f1ea783fd"}	f	f	2026-09-03 03:17:06.762027+00
224d9258-7400-4303-a030-96568f68d8b2	35bb12a9-b2c6-4f77-b383-307759714318	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "c2e3fd6f-14b7-4147-87ff-a7f78d92592e"}	f	f	2026-09-03 03:17:41.009538+00
aeefa018-9f83-4eed-ba0a-d5d11f75d6c8	3be2026d-ea02-43f3-bc41-e0b3e9bb133c	Booking update	Your booking status changed to on_the_way	{"type": "booking_status", "booking_id": "c2e3fd6f-14b7-4147-87ff-a7f78d92592e"}	f	f	2026-09-03 03:18:51.648098+00
2a16fe84-0df3-46df-be8e-aee144c8e037	35bb12a9-b2c6-4f77-b383-307759714318	New consultation booking request	A customer wants to schedule a live video consultation with you at 3 Sep, 7:00 PM. Please confirm.	{"type": "consultation_scheduled_request", "consultation_id": "fc5b82a7-8f4f-4f49-a342-cc34776ee130"}	f	f	2026-09-03 03:21:48.919325+00
1dd87e01-cd46-40e0-9734-0aee7390dd08	35bb12a9-b2c6-4f77-b383-307759714318	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "49c23089-e873-4e38-8ce0-52da9a4f2787"}	f	f	2026-09-03 03:36:07.607476+00
ec07451e-f15f-43d2-9e37-e7b43be9aff0	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to on_the_way	{"type": "booking_status", "booking_id": "49c23089-e873-4e38-8ce0-52da9a4f2787"}	f	f	2026-09-03 03:36:12.505329+00
591f0768-a689-46fc-a054-fa20a0e13e1f	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to arrived	{"type": "booking_status", "booking_id": "49c23089-e873-4e38-8ce0-52da9a4f2787"}	f	f	2026-09-03 03:36:13.72519+00
9c172757-4e27-47ab-814d-d815714290b7	aebfbed2-7205-437b-9045-65d1b0240e6a	Invoice ready	Your technician has completed the job. Amount due: ₹179.00. Tap to pay.	{"type": "invoice_ready", "booking_id": "49c23089-e873-4e38-8ce0-52da9a4f2787", "final_price": "179.00"}	f	f	2026-09-03 04:04:56.842493+00
321d7946-5db6-49fc-910a-bdf38ce05123	35bb12a9-b2c6-4f77-b383-307759714318	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "d115aac1-8291-4fff-9010-dc78e5281247"}	f	f	2026-09-03 04:06:03.381855+00
96263495-8cac-4ace-9991-7060f0247b5a	35bb12a9-b2c6-4f77-b383-307759714318	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "2041b386-bc65-469a-b8e4-10bb153d8d69"}	f	f	2026-09-03 05:03:09.435212+00
4c76b51b-4c47-4a44-8507-07e1279af967	35bb12a9-b2c6-4f77-b383-307759714318	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "8627b7bb-ca01-484d-918d-fbd552855a4b"}	f	f	2026-09-03 05:32:18.841582+00
c75df42f-ce26-4c55-bfb8-d7eb4e06d7a1	35bb12a9-b2c6-4f77-b383-307759714318	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "619e39f7-7322-43d9-9b7f-199a6e826c67"}	f	f	2026-09-03 05:32:53.261724+00
9deb8f80-dcf4-4120-87a9-8d10888b2f4b	3e09db72-8f82-49c5-81b4-b95be21ea46f	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "6cfc011e-04f5-422f-8f42-e4e073364b39"}	f	f	2026-09-03 05:33:13.27836+00
04d38d88-7501-44a8-8d9b-e4cd556fd325	35bb12a9-b2c6-4f77-b383-307759714318	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "1b30f148-2d8f-4401-8d70-7a7d2311e88b"}	f	f	2026-09-03 05:37:53.200459+00
95fbc5ff-f75a-4033-9614-8f0376a93b91	35bb12a9-b2c6-4f77-b383-307759714318	New consultation request	A customer is requesting a live video consultation.	{"type": "consultation_request", "consultation_id": "a8501454-e22a-4600-8170-5a10ce8e639e"}	f	f	2026-09-03 05:54:58.841925+00
c8a8da81-caf6-4b5f-af91-9aebb63c6ba8	35bb12a9-b2c6-4f77-b383-307759714318	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "7fa3e04d-2fba-467f-961e-55610b39ac8c"}	f	f	2026-09-03 05:55:09.6023+00
2693f3cc-6c8c-4c74-bca7-5d0f783ec7c6	35bb12a9-b2c6-4f77-b383-307759714318	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "82b00ea2-a795-4bde-aa78-8cd9956f14bc"}	f	f	2026-09-03 05:55:37.422355+00
488e9b5d-bcc2-4378-b930-ceb46be02313	3be2026d-ea02-43f3-bc41-e0b3e9bb133c	Booking update	Your booking status changed to on_the_way	{"type": "booking_status", "booking_id": "82b00ea2-a795-4bde-aa78-8cd9956f14bc"}	f	f	2026-09-03 06:29:28.439292+00
d6425309-e9e3-4dc2-9e48-6e36af113aaa	3be2026d-ea02-43f3-bc41-e0b3e9bb133c	Booking update	Your booking status changed to arrived	{"type": "booking_status", "booking_id": "82b00ea2-a795-4bde-aa78-8cd9956f14bc"}	f	f	2026-09-03 06:29:30.619483+00
610be353-77f1-47c6-af33-672d5f55f341	35bb12a9-b2c6-4f77-b383-307759714318	New consultation booking request	A customer wants to schedule a live video consultation with you at 3 Sep, 7:37 AM. Please confirm.	{"type": "consultation_scheduled_request", "consultation_id": "41c44d17-6822-4eeb-88a9-c00a686f40b9"}	f	f	2026-09-03 06:37:24.560046+00
9c247a5e-1e98-4569-963d-0ac3d5f520e2	35bb12a9-b2c6-4f77-b383-307759714318	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "84bae57a-641a-4404-b616-866208e4dd33"}	f	f	2026-09-03 06:45:12.666959+00
1575b735-adca-4850-87db-b842b0587ff4	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to on_the_way	{"type": "booking_status", "booking_id": "84bae57a-641a-4404-b616-866208e4dd33"}	f	f	2026-09-03 06:45:45.294483+00
df8fb2f2-7249-4d66-8c8e-e63fddb83728	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to arrived	{"type": "booking_status", "booking_id": "84bae57a-641a-4404-b616-866208e4dd33"}	t	f	2026-09-03 06:45:46.926159+00
625096c1-97f6-47de-a396-8f59a68ffb0e	35bb12a9-b2c6-4f77-b383-307759714318	New consultation request	A customer is requesting a live video consultation.	{"type": "consultation_request", "consultation_id": "0fc55c02-7993-4298-8e1e-68d6e4147321"}	f	f	2026-09-03 07:14:22.572074+00
41b8ff05-29e9-415e-b05b-ec5da74a4ddd	35bb12a9-b2c6-4f77-b383-307759714318	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "782acec4-53bb-49b2-8795-313d35eb31ea"}	f	f	2026-09-03 07:15:11.619351+00
63744846-ac0e-4093-b978-411878ed8ec2	35bb12a9-b2c6-4f77-b383-307759714318	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "d41d3e67-58a8-4739-b603-915c37570718"}	f	f	2026-09-03 07:17:52.9126+00
ebf1e4c9-a361-40e5-9cdb-eaef04b91ba4	3be2026d-ea02-43f3-bc41-e0b3e9bb133c	Booking update	Your booking status changed to on_the_way	{"type": "booking_status", "booking_id": "d41d3e67-58a8-4739-b603-915c37570718"}	f	f	2026-09-03 07:17:58.554494+00
c8bd4eee-1883-4ebd-99e0-1263aec3fd8d	3be2026d-ea02-43f3-bc41-e0b3e9bb133c	Booking update	Your booking status changed to arrived	{"type": "booking_status", "booking_id": "d41d3e67-58a8-4739-b603-915c37570718"}	f	f	2026-09-03 07:18:00.442524+00
15af2062-de3a-47b2-878a-e0f97becb514	35bb12a9-b2c6-4f77-b383-307759714318	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "56aca21f-96e2-4382-a098-5fa364070cb5"}	f	f	2026-09-03 07:18:14.944235+00
f526bd8e-5254-460f-b038-5d1073c5173d	3be2026d-ea02-43f3-bc41-e0b3e9bb133c	Booking update	Your booking status changed to on_the_way	{"type": "booking_status", "booking_id": "56aca21f-96e2-4382-a098-5fa364070cb5"}	f	f	2026-09-03 07:18:20.213753+00
2cb3af24-d377-4d01-bf48-10bdeb596191	3be2026d-ea02-43f3-bc41-e0b3e9bb133c	Booking update	Your booking status changed to arrived	{"type": "booking_status", "booking_id": "56aca21f-96e2-4382-a098-5fa364070cb5"}	f	f	2026-09-03 07:18:21.302172+00
db9b0e8b-2535-45a6-8aa4-13712a0f6ee2	35bb12a9-b2c6-4f77-b383-307759714318	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "12dd8936-488e-48c8-8312-122fb8cc53f5"}	f	f	2026-09-03 08:05:39.92212+00
d732de63-e572-459a-971d-624221ae1bbf	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to on_the_way	{"type": "booking_status", "booking_id": "12dd8936-488e-48c8-8312-122fb8cc53f5"}	f	f	2026-09-03 08:06:37.144095+00
43c42ef2-b2d9-4783-b605-d93db12dc408	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to arrived	{"type": "booking_status", "booking_id": "12dd8936-488e-48c8-8312-122fb8cc53f5"}	f	f	2026-09-03 08:06:43.652485+00
6de16658-7e87-4dfa-86c8-abef51f5f4fa	35bb12a9-b2c6-4f77-b383-307759714318	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "50ed0da7-a6ef-43ce-8f40-a1f79c284c22"}	f	f	2026-09-03 08:08:19.255237+00
9536fd46-d37d-4778-a510-93205a5fb7cc	35bb12a9-b2c6-4f77-b383-307759714318	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "86a89aef-ad60-4443-bd89-710892e93df4"}	f	f	2026-09-03 08:38:54.02676+00
f335cb90-cb0e-4d44-b13a-f44dc3ebb66d	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to on_the_way	{"type": "booking_status", "booking_id": "86a89aef-ad60-4443-bd89-710892e93df4"}	f	f	2026-09-03 08:39:08.572717+00
919a0001-8127-48aa-a01d-cf11e47d26a9	35bb12a9-b2c6-4f77-b383-307759714318	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "bcde4eec-26b8-4c7a-b71a-bbb56a8b8c2b"}	f	f	2026-09-03 08:39:21.676712+00
7ae0ef8c-d2c5-4a79-945f-0e7aab4fede6	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to on_the_way	{"type": "booking_status", "booking_id": "bcde4eec-26b8-4c7a-b71a-bbb56a8b8c2b"}	f	f	2026-09-03 08:39:30.439526+00
82298ee1-a2a9-42de-948c-71e3aaa5faf2	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to arrived	{"type": "booking_status", "booking_id": "bcde4eec-26b8-4c7a-b71a-bbb56a8b8c2b"}	f	f	2026-09-03 08:39:36.562017+00
1aeed561-7e61-46cf-b836-92a5756cf792	35bb12a9-b2c6-4f77-b383-307759714318	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "5ccde187-b272-449f-8d77-cf20b2d50540"}	f	f	2026-09-03 08:40:37.866485+00
9b0db856-c439-4584-a657-3347b3c0b114	35bb12a9-b2c6-4f77-b383-307759714318	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "b85f589c-990b-4905-89ab-0af5524b6001"}	f	f	2026-09-03 09:16:49.198163+00
d5bdc16f-9e7f-4cc0-ab62-13a55b52aa8b	35bb12a9-b2c6-4f77-b383-307759714318	New consultation request	A customer is requesting a live video consultation.	{"type": "consultation_request", "consultation_id": "bf98f7d6-008b-49f2-a552-85d41c210bf4"}	f	f	2026-09-03 09:18:35.776272+00
15b99e82-3294-4b3c-86db-1b7168ab2aa2	aebfbed2-7205-437b-9045-65d1b0240e6a	Call not answered	The technician couldn't take your live video consultation right now.	{"type": "consultation_rejected", "reason": "", "consultation_id": "bf98f7d6-008b-49f2-a552-85d41c210bf4"}	f	f	2026-09-03 09:19:34.091061+00
40317f46-f311-4fb6-823b-a988d63f7842	35bb12a9-b2c6-4f77-b383-307759714318	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "053e8dfd-cfb9-470d-995c-be55481732e0"}	f	f	2026-09-03 10:36:53.913499+00
37692dcf-2e23-4147-ae7f-01ca1a2bb13a	35bb12a9-b2c6-4f77-b383-307759714318	New message	Hiiiii	{"type": "booking_message", "booking_id": "053e8dfd-cfb9-470d-995c-be55481732e0"}	f	f	2026-09-03 11:41:40.013782+00
9f5230de-dc93-4844-b140-736e589b7e40	aebfbed2-7205-437b-9045-65d1b0240e6a	New message	Hiiiiiii	{"type": "booking_message", "booking_id": "053e8dfd-cfb9-470d-995c-be55481732e0"}	f	f	2026-09-03 11:41:48.354059+00
de3f2529-00a2-4e1d-bed0-f917c25d5640	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to on_the_way	{"type": "booking_status", "booking_id": "50ed0da7-a6ef-43ce-8f40-a1f79c284c22"}	f	f	2026-09-03 11:47:00.888158+00
3eb124db-2c9a-41e6-a01c-9e01418e2a66	35bb12a9-b2c6-4f77-b383-307759714318	New consultation request	A customer is requesting a live video consultation.	{"type": "consultation_request", "consultation_id": "ba2519c2-8112-4ee3-ace6-bf1ead3e1783"}	f	f	2026-09-03 11:48:25.174582+00
af42b943-9890-4f41-8c9d-b2ec51ac145b	35bb12a9-b2c6-4f77-b383-307759714318	New consultation request	A customer is requesting a live video consultation.	{"type": "consultation_request", "consultation_id": "a686447d-43cc-4a26-b10e-a299cb7224bb"}	f	f	2026-09-03 11:48:40.490331+00
154b3a57-d093-49f4-9ba9-222de7960757	35bb12a9-b2c6-4f77-b383-307759714318	New consultation request	A customer is requesting a live video consultation.	{"type": "consultation_request", "consultation_id": "851c31df-9c1a-436d-9b76-ec5b19ef40fe"}	f	f	2026-09-04 02:13:51.215919+00
16180aa2-a486-449c-8132-7fc98b1f3fb4	35bb12a9-b2c6-4f77-b383-307759714318	New consultation request	A customer is requesting a live video consultation.	{"type": "consultation_request", "consultation_id": "bdcc241b-a4b9-4c1e-a482-3e65bb0b4fc2"}	f	f	2026-09-04 02:28:54.709395+00
a234075a-8be2-4aa5-94d2-96a199fda523	3e09db72-8f82-49c5-81b4-b95be21ea46f	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "8d322e61-9b4f-43cb-a8c9-f70d0deb9f8a"}	f	f	2026-09-04 02:33:35.317269+00
18d92250-bb7e-4d41-bff7-107bb7e4088c	35bb12a9-b2c6-4f77-b383-307759714318	New consultation request	A customer is requesting a live video consultation.	{"type": "consultation_request", "consultation_id": "42dabaed-2a39-4814-a067-8c78d776d5fe"}	f	f	2026-09-04 02:34:09.091401+00
0987c2ff-fe16-4a98-a5c0-432f72f3caec	35bb12a9-b2c6-4f77-b383-307759714318	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "c0caeee6-61ff-4109-991d-dc8705ea41d3"}	f	f	2026-09-04 02:35:21.259753+00
6c3adcba-2355-4005-9a5e-871df91ab2cb	35bb12a9-b2c6-4f77-b383-307759714318	New consultation request	A customer is requesting a live video consultation.	{"type": "consultation_request", "consultation_id": "614f30f5-ae43-4876-9c7e-4186c4e51f9c"}	f	f	2026-09-04 02:35:37.874368+00
bd7d1f72-5384-40f6-8b9e-e95fbced9ff5	9dd63068-5ba2-487e-ab79-aa0bb4f686f5	Technician's recommendation is ready	Your technician sent a recommendation after the call. Review it to book a visit.	{"type": "consultation_recommendation", "consultation_id": "614f30f5-ae43-4876-9c7e-4186c4e51f9c"}	t	f	2026-09-04 02:36:12.706842+00
81c13dc8-f919-4297-a632-37d8c59e6e8d	35bb12a9-b2c6-4f77-b383-307759714318	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "9a29e88d-004c-42d5-84b1-e48bb8c9dd06"}	f	f	2026-09-04 02:37:11.745473+00
62f8837b-1d5c-4f24-895e-49e4160eaabe	9dd63068-5ba2-487e-ab79-aa0bb4f686f5	Booking update	Your booking status changed to on_the_way	{"type": "booking_status", "booking_id": "c0caeee6-61ff-4109-991d-dc8705ea41d3"}	t	f	2026-09-04 02:37:44.899783+00
6213aa71-35a5-494b-b720-b87ad48374f7	9dd63068-5ba2-487e-ab79-aa0bb4f686f5	Booking update	Your booking status changed to arrived	{"type": "booking_status", "booking_id": "c0caeee6-61ff-4109-991d-dc8705ea41d3"}	t	f	2026-09-04 02:37:56.250958+00
1a6cfbd2-a369-4698-a7f7-867c082b9c18	9dd63068-5ba2-487e-ab79-aa0bb4f686f5	Consultation accepted	A technician has accepted your live video consultation. Connecting now...	{"type": "consultation_accepted", "consultation_id": "614f30f5-ae43-4876-9c7e-4186c4e51f9c"}	t	f	2026-09-04 02:35:40.305677+00
081dfee7-cb8a-40b3-9cd4-9deca84696e1	9dd63068-5ba2-487e-ab79-aa0bb4f686f5	Consultation accepted	A technician has accepted your live video consultation. Connecting now...	{"type": "consultation_accepted", "consultation_id": "42dabaed-2a39-4814-a067-8c78d776d5fe"}	t	f	2026-09-04 02:34:41.127144+00
9d7fac77-6397-4b32-a376-95c43e35d495	9dd63068-5ba2-487e-ab79-aa0bb4f686f5	Booking update	Your booking status changed to on_the_way	{"type": "booking_status", "booking_id": "9a29e88d-004c-42d5-84b1-e48bb8c9dd06"}	f	f	2026-09-04 03:02:16.116374+00
4f6e2b5c-d24b-46db-a629-3dc383740c44	9dd63068-5ba2-487e-ab79-aa0bb4f686f5	Booking update	Your booking status changed to arrived	{"type": "booking_status", "booking_id": "9a29e88d-004c-42d5-84b1-e48bb8c9dd06"}	f	f	2026-09-04 03:02:17.274941+00
b0ccea93-e9d8-4712-82b5-7efa3409a9d2	35bb12a9-b2c6-4f77-b383-307759714318	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "ffb0bbac-d969-49c0-b9f4-51c9ae747776"}	f	f	2026-09-04 03:13:26.29927+00
1fa29ec0-81c3-4346-b1ad-928138368a33	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to on_the_way	{"type": "booking_status", "booking_id": "ffb0bbac-d969-49c0-b9f4-51c9ae747776"}	f	f	2026-09-04 03:13:43.756078+00
0c7d3c4c-5cda-4fd8-8a4e-a4910ed408eb	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to arrived	{"type": "booking_status", "booking_id": "ffb0bbac-d969-49c0-b9f4-51c9ae747776"}	f	f	2026-09-04 03:13:45.12068+00
15b7397d-bda2-4e3c-97ea-b9e877cf7ecd	35bb12a9-b2c6-4f77-b383-307759714318	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "9aadbad3-538f-4771-9f4c-23fc70689baa"}	f	f	2026-09-04 04:00:48.553148+00
2a79eab9-52d6-49c8-bcb9-ce5cc6587189	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to on_the_way	{"type": "booking_status", "booking_id": "9aadbad3-538f-4771-9f4c-23fc70689baa"}	f	f	2026-09-04 04:00:57.63029+00
47b9b289-91f5-44d7-8956-120d7e565306	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to arrived	{"type": "booking_status", "booking_id": "9aadbad3-538f-4771-9f4c-23fc70689baa"}	f	f	2026-09-04 04:01:06.667486+00
2ea56668-8530-4a42-be35-f49d86f79999	aebfbed2-7205-437b-9045-65d1b0240e6a	Invoice ready	Your technician has completed the job. Amount due: ₹179.00. Tap to pay.	{"type": "invoice_ready", "booking_id": "9aadbad3-538f-4771-9f4c-23fc70689baa", "final_price": "179.00"}	f	f	2026-09-04 04:09:19.837509+00
37e15084-45b6-441c-9bfb-87a7fe687a35	35bb12a9-b2c6-4f77-b383-307759714318	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "030ece2b-efa3-4d52-8777-f6f4624825e2"}	f	f	2026-09-04 04:09:25.789616+00
ed7c4a68-9a0e-4f97-8729-a5fe68dc1d2c	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to on_the_way	{"type": "booking_status", "booking_id": "030ece2b-efa3-4d52-8777-f6f4624825e2"}	f	f	2026-09-04 04:09:31.525205+00
29f0f084-22ef-4c9c-b47d-d9eab1934cd4	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to arrived	{"type": "booking_status", "booking_id": "030ece2b-efa3-4d52-8777-f6f4624825e2"}	f	f	2026-09-04 04:09:33.293888+00
8df87931-5ff3-4dd3-a95b-d075dea37c35	aebfbed2-7205-437b-9045-65d1b0240e6a	Call not answered	The technician couldn't take your live video consultation right now.	{"type": "consultation_rejected", "reason": "", "consultation_id": "ba2519c2-8112-4ee3-ace6-bf1ead3e1783"}	f	f	2026-09-04 04:11:02.506923+00
f52e5b8f-3ff9-45cc-94cf-b5bac413d63a	35bb12a9-b2c6-4f77-b383-307759714318	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "b6386401-faf3-4bc9-b3fa-01981e0c3c35"}	f	f	2026-09-04 04:44:16.827158+00
551473fa-c4f6-4664-8104-95ec54e40cd8	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to on_the_way	{"type": "booking_status", "booking_id": "b6386401-faf3-4bc9-b3fa-01981e0c3c35"}	f	f	2026-09-04 04:44:36.033256+00
2431ea70-bce5-4540-b69c-6bc325d3d78a	aebfbed2-7205-437b-9045-65d1b0240e6a	Invoice ready	Your technician has completed the job. Amount due: ₹179.00. Tap to pay.	{"type": "invoice_ready", "booking_id": "b6386401-faf3-4bc9-b3fa-01981e0c3c35", "final_price": "179.00"}	t	f	2026-09-04 04:45:11.433031+00
d5a904af-b734-4021-923d-6490b44ac39c	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to arrived	{"type": "booking_status", "booking_id": "b6386401-faf3-4bc9-b3fa-01981e0c3c35"}	t	f	2026-09-04 04:44:40.650713+00
fd2fb717-9028-4b98-9d71-854eb9910aa2	3e09db72-8f82-49c5-81b4-b95be21ea46f	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "8031861e-f08c-4431-8c05-b8fa2ca57f40"}	f	f	2026-09-04 05:31:05.961137+00
11f9460b-b3c1-4148-9f54-19a3050dfc4f	35bb12a9-b2c6-4f77-b383-307759714318	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "e7cfec2d-65be-4642-9512-30a6fde5df38"}	f	f	2026-09-04 05:52:15.05536+00
612d0167-8e19-4e9c-979a-0945fbe78112	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to on_the_way	{"type": "booking_status", "booking_id": "e7cfec2d-65be-4642-9512-30a6fde5df38"}	f	f	2026-09-04 05:53:11.168561+00
eac82a26-ed5d-4366-bc8b-8a8f1ec84f3e	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to arrived	{"type": "booking_status", "booking_id": "e7cfec2d-65be-4642-9512-30a6fde5df38"}	f	f	2026-09-04 05:53:15.089229+00
f5554a7a-0088-4913-ab2d-4f5d0d6609f1	aebfbed2-7205-437b-9045-65d1b0240e6a	Invoice ready	Your technician has completed the job. Amount due: ₹179.00. Tap to pay.	{"type": "invoice_ready", "booking_id": "e7cfec2d-65be-4642-9512-30a6fde5df38", "final_price": "179.00"}	t	f	2026-09-04 05:53:27.033873+00
00e00022-5786-43e9-b7cb-03c7afd57e94	aebfbed2-7205-437b-9045-65d1b0240e6a	Consultation accepted	A technician has accepted your live video consultation. Connecting now...	{"type": "consultation_accepted", "consultation_id": "a686447d-43cc-4a26-b10e-a299cb7224bb"}	f	f	2026-09-04 07:05:16.424565+00
d97e3781-a9d2-4f2b-93cd-a340e4f79b1a	aebfbed2-7205-437b-9045-65d1b0240e6a	New message	Hiii	{"type": "booking_message", "booking_id": "e7cfec2d-65be-4642-9512-30a6fde5df38"}	f	f	2026-09-04 07:05:46.450355+00
994a6d37-8807-4073-8267-9bd45ef715ab	35bb12a9-b2c6-4f77-b383-307759714318	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "1ac4424a-57da-4946-adf8-3260b1dcfe3c"}	f	f	2026-09-04 07:12:43.073084+00
8f35598c-d7c3-45a1-8b13-3fa124ba245f	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to on_the_way	{"type": "booking_status", "booking_id": "1ac4424a-57da-4946-adf8-3260b1dcfe3c"}	f	f	2026-09-04 07:13:20.867784+00
b217da16-ae1f-4d20-81e9-739770f7ccb9	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to arrived	{"type": "booking_status", "booking_id": "1ac4424a-57da-4946-adf8-3260b1dcfe3c"}	f	f	2026-09-04 07:13:22.044349+00
89eb8220-abf4-4fa7-80b8-d801c1887dba	aebfbed2-7205-437b-9045-65d1b0240e6a	Invoice ready	Your technician has completed the job. Amount due: ₹179.00. Tap to pay.	{"type": "invoice_ready", "booking_id": "1ac4424a-57da-4946-adf8-3260b1dcfe3c", "final_price": "179.00"}	f	f	2026-09-04 07:13:35.446921+00
ba55d8a8-dd29-407f-9b62-0dd10eafd31d	35bb12a9-b2c6-4f77-b383-307759714318	New message	Hiii	{"type": "booking_message", "booking_id": "1ac4424a-57da-4946-adf8-3260b1dcfe3c"}	f	f	2026-09-04 07:20:51.089496+00
c83a18ad-d273-4480-972a-34ea46a97170	aebfbed2-7205-437b-9045-65d1b0240e6a	New message	Hiiiii	{"type": "booking_message", "booking_id": "1ac4424a-57da-4946-adf8-3260b1dcfe3c"}	f	f	2026-09-04 07:21:09.49626+00
94fd1759-ce49-41d5-8fe2-fa6a31c10091	35bb12a9-b2c6-4f77-b383-307759714318	New message	Hiiii	{"type": "booking_message", "booking_id": "1ac4424a-57da-4946-adf8-3260b1dcfe3c"}	f	t	2026-09-04 07:27:22.746484+00
a715fb13-2acc-4816-aeec-bb1c0d09ed85	35bb12a9-b2c6-4f77-b383-307759714318	New message	Hiii	{"type": "booking_message", "booking_id": "1ac4424a-57da-4946-adf8-3260b1dcfe3c"}	f	t	2026-09-04 07:30:27.452736+00
d9938a62-84c4-45e1-9d0b-d40889a2681f	aebfbed2-7205-437b-9045-65d1b0240e6a	New message	Hiii	{"type": "booking_message", "booking_id": "1ac4424a-57da-4946-adf8-3260b1dcfe3c"}	f	f	2026-09-04 07:49:12.532971+00
f3e06c3f-68e8-48fe-b926-f1bd5fa410ab	35bb12a9-b2c6-4f77-b383-307759714318	New message	Hiii	{"type": "booking_message", "booking_id": "1ac4424a-57da-4946-adf8-3260b1dcfe3c"}	f	f	2026-09-04 07:53:10.879764+00
028758cb-e116-4f42-8e02-77029a5fa0d0	3be2026d-ea02-43f3-bc41-e0b3e9bb133c	Booking update	Your booking status changed to arrived	{"type": "booking_status", "booking_id": "c2e3fd6f-14b7-4147-87ff-a7f78d92592e"}	t	f	2026-09-03 11:47:12.829503+00
97427c87-0006-4fb0-b7f8-423665279aca	35bb12a9-b2c6-4f77-b383-307759714318	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "4a8fb8f6-8129-4b01-99ff-e2664b45214d"}	f	t	2026-09-04 08:55:48.686387+00
00d0fd35-9e74-4cf0-b8e1-5e7f27d9c48e	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to on_the_way	{"type": "booking_status", "booking_id": "4a8fb8f6-8129-4b01-99ff-e2664b45214d"}	f	t	2026-09-04 08:56:07.901877+00
219e18da-0322-40cd-aa97-49d8142eaae2	aebfbed2-7205-437b-9045-65d1b0240e6a	Booking update	Your booking status changed to arrived	{"type": "booking_status", "booking_id": "4a8fb8f6-8129-4b01-99ff-e2664b45214d"}	f	t	2026-09-04 08:56:10.491556+00
d2c655a3-45a2-4d97-8479-5e934320911e	aebfbed2-7205-437b-9045-65d1b0240e6a	Invoice ready	Your technician has completed the job. Amount due: ₹179.00. Tap to pay. This service is covered by a 15-day warranty.	{"type": "invoice_ready", "booking_id": "4a8fb8f6-8129-4b01-99ff-e2664b45214d", "final_price": "179.00"}	f	t	2026-09-04 08:56:38.558304+00
d7535997-4eef-43a9-93c5-e0b2c0461c1e	35bb12a9-b2c6-4f77-b383-307759714318	New consultation request	A customer is requesting a live video consultation.	{"type": "consultation_request", "consultation_id": "dcb15e78-261e-4cd1-9fab-ba5f1d25f88d"}	f	t	2026-09-04 08:58:50.918951+00
bba59b6f-4bf7-424d-ab54-b110aff6a5da	aebfbed2-7205-437b-9045-65d1b0240e6a	Consultation accepted	A technician has accepted your live video consultation. Connecting now...	{"type": "consultation_accepted", "consultation_id": "851c31df-9c1a-436d-9b76-ec5b19ef40fe"}	f	t	2026-09-04 08:58:53.2679+00
98b7da50-e637-4e7b-aa53-eb82acf04a72	35bb12a9-b2c6-4f77-b383-307759714318	New consultation request	A customer is requesting a live video consultation.	{"type": "consultation_request", "consultation_id": "82d91fe5-5e12-4ef6-a973-ac2ba17de0a5"}	f	t	2026-09-04 08:59:18.568263+00
3c127465-a06a-42ce-b059-82507cd64728	aebfbed2-7205-437b-9045-65d1b0240e6a	Consultation accepted	A technician has accepted your live video consultation. Connecting now...	{"type": "consultation_accepted", "consultation_id": "82d91fe5-5e12-4ef6-a973-ac2ba17de0a5"}	f	t	2026-09-04 08:59:22.879986+00
04b8642a-85ed-4c7a-872c-eb6dd691e8b6	aebfbed2-7205-437b-9045-65d1b0240e6a	Technician's recommendation is ready	Your technician sent a recommendation after the call. Review it to book a visit.	{"type": "consultation_recommendation", "consultation_id": "82d91fe5-5e12-4ef6-a973-ac2ba17de0a5"}	f	t	2026-09-04 09:03:29.719516+00
916ccf4a-80e9-49c8-a8d1-2bd921eaef17	35bb12a9-b2c6-4f77-b383-307759714318	New booking request	You have a new booking request.	{"type": "booking_assigned", "booking_id": "9a8facc2-f8c9-4721-aebb-45615a91aa2d"}	f	t	2026-09-04 09:03:53.832621+00
915ea4f7-6811-4425-aaa7-8e4d3c55ca78	35bb12a9-b2c6-4f77-b383-307759714318	New message	Hii	{"type": "booking_message", "booking_id": "9a8facc2-f8c9-4721-aebb-45615a91aa2d"}	f	t	2026-09-07 06:41:45.369253+00
\.


--
-- Data for Name: payments; Type: TABLE DATA; Schema: public; Owner: homefix_db_wuc1_user
--

COPY public.payments (id, booking_id, user_id, amount, currency, method, status, created_at, updated_at, transaction_ref, upi_txn_id, invoice_number, upi_status, upi_response_code, upi_approval_ref, verified, platform_commission, technician_earning, refunded_at, base_amount, gst_amount, gst_percent, is_repeat_customer, repeat_discount_percent, repeat_discount_amount, cgst_amount, sgst_amount, razorpay_order_id, razorpay_payment_id, razorpay_signature, platform_fee_amount, visit_charge_amount) FROM stdin;
89e44e59-cf5c-4a55-8e50-8b4d7c56aeec	6159f686-4eca-4829-8984-8d748016d126	aebfbed2-7205-437b-9045-65d1b0240e6a	447.28	INR	razorpay	paid	2026-08-29 07:24:02.781651+00	2026-08-29 07:24:26.447356+00	HF1787988242f653761ea1b1289e	\N	INV-202608-89e44e59	\N	\N	\N	t	56.86	322.19	\N	379.05	68.23	18.00	t	5	19.95	34.12	34.12	\N	\N	\N	\N	\N
4f8cc0cc-fb0f-4659-80ca-a93a619ce5c2	e70405d7-2471-42eb-b587-8f8242a67a01	dc3f702c-b385-4c27-9057-0325c0b5013d	335.18	INR	\N	failed	2026-08-29 06:47:06.433208+00	2026-08-29 06:47:14.38093+00	HF1787986025a2ec3a1889899f36	\N	\N	FAILED	\N	\N	f	\N	\N	\N	284.05	51.13	18.00	t	5	14.95	25.57	25.56	\N	\N	\N	\N	\N
\.


--
-- Data for Name: reviews; Type: TABLE DATA; Schema: public; Owner: homefix_db_wuc1_user
--

COPY public.reviews (id, booking_id, customer_id, technician_id, rating, comment, created_at, consultation_id) FROM stdin;
64c9e438-906c-46fd-9f12-a07311e06eae	6159f686-4eca-4829-8984-8d748016d126	aebfbed2-7205-437b-9045-65d1b0240e6a	e9977c7e-f0a5-4284-95a6-f535a31b0c9f	5		2026-09-03 11:42:39.18622+00	\N
4959a280-9906-4c28-9aeb-7c66a1f507be	49c23089-e873-4e38-8ce0-52da9a4f2787	aebfbed2-7205-437b-9045-65d1b0240e6a	e894f942-a1c6-420d-801f-0f73b8921856	2	nice service	2026-09-04 03:51:05.349622+00	\N
\.


--
-- Data for Name: spare_part_orders; Type: TABLE DATA; Schema: public; Owner: homefix_db_wuc1_user
--

COPY public.spare_part_orders (id, spare_part_id, supplier_id, quantity, unit_cost, status, ordered_by, created_at, received_at) FROM stdin;
\.


--
-- Data for Name: spare_part_stock_movements; Type: TABLE DATA; Schema: public; Owner: homefix_db_wuc1_user
--

COPY public.spare_part_stock_movements (id, spare_part_id, change_type, quantity_delta, booking_id, note, created_by, created_at) FROM stdin;
\.


--
-- Data for Name: spare_parts; Type: TABLE DATA; Schema: public; Owner: homefix_db_wuc1_user
--

COPY public.spare_parts (id, category_id, supplier_id, name, sku, description, unit_price, stock_quantity, reorder_level, is_active, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: suppliers; Type: TABLE DATA; Schema: public; Owner: homefix_db_wuc1_user
--

COPY public.suppliers (id, name, contact_person, phone, email, address, is_active, created_at) FROM stdin;
\.


--
-- Data for Name: technicians; Type: TABLE DATA; Schema: public; Owner: homefix_db_wuc1_user
--

COPY public.technicians (id, user_id, category_id, experience_years, rating_avg, rating_count, is_verified, is_available, current_lat, current_lng, created_at, updated_at, address, government_id_url, profile_photo_url, approval_status, rejection_reason, working_hours) FROM stdin;
ff7fa15e-6118-4cc5-9939-5d1e34799898	3e09db72-8f82-49c5-81b4-b95be21ea46f	67870415-027c-4371-814b-3d80c0f67b7f	2	0.00	0	t	t	\N	\N	2026-08-29 06:38:46.83885+00	2026-08-29 06:45:14.221308+00	Bhandup West	http://localhost:8080/uploads/8383ca8f-8e4b-4b7a-9c34-446ae4816c36.jpg	http://localhost:8080/uploads/6a3528cc-02fb-4cfe-9045-0827aae61fc4.jpg	approved		{"fri": {"open": "09:00", "close": "18:00"}, "mon": {"open": "09:00", "close": "18:00"}, "sat": {"open": "09:00", "close": "18:00"}, "sun": null, "thu": {"open": "09:00", "close": "18:00"}, "tue": {"open": "09:00", "close": "18:00"}, "wed": {"open": "09:00", "close": "18:00"}}
56e6825f-1d28-4030-9831-8179f43ed3a8	a5bcbdcb-965d-4e7e-843b-7e16cfd43eb4	763c06cc-2221-40d6-93db-9557a7c47aec	2	0.00	0	t	t	\N	\N	2026-08-29 08:09:16.292541+00	2026-08-31 05:25:43.313972+00	Bhandup	http://localhost:8080/uploads/6a601aa9-3225-484c-8f42-9303c07715fc.jpg	http://localhost:8080/uploads/c64abd35-f41e-4bbb-84d5-0f3f7ad5d129.jpg	approved		{"fri": {"open": "09:00", "close": "18:00"}, "mon": {"open": "09:00", "close": "18:00"}, "sat": {"open": "09:00", "close": "18:00"}, "sun": null, "thu": {"open": "09:00", "close": "18:00"}, "tue": {"open": "09:00", "close": "18:00"}, "wed": {"open": "09:00", "close": "18:00"}}
e9977c7e-f0a5-4284-95a6-f535a31b0c9f	8ce31a51-34d2-45ac-bbdd-0069413f6b3a	1951b819-8776-4183-80ab-ea271aac9e85	2	5.00	1	t	t	\N	\N	2026-08-29 07:20:18.807717+00	2026-09-03 11:42:39.18622+00	Ghansoli	http://localhost:8080/uploads/9b38fd2b-4c7a-49c9-a687-d7070a8926ee.jpg	http://localhost:8080/uploads/66f10fb4-3367-489b-94c1-1134abf91708.jpg	approved		{"fri": {"open": "09:00", "close": "18:00"}, "mon": {"open": "09:00", "close": "18:00"}, "sat": {"open": "09:00", "close": "18:00"}, "sun": null, "thu": {"open": "09:00", "close": "18:00"}, "tue": {"open": "09:00", "close": "18:00"}, "wed": {"open": "09:00", "close": "18:00"}}
e894f942-a1c6-420d-801f-0f73b8921856	35bb12a9-b2c6-4f77-b383-307759714318	297f8069-7bb8-4948-a50b-51cd88ba2998	1	2.00	1	t	t	\N	\N	2026-08-31 06:58:49.914996+00	2026-09-04 04:00:24.257395+00	Koparkhairane	http://localhost:8080/uploads/2ee7cafc-506b-4abe-ae30-3ec4bf344962.jpg	http://localhost:8080/uploads/b914d237-6765-4bdd-bfbf-37e7412bc4ff.jpg	approved		{"fri": {"open": "09:00", "close": "18:00"}, "mon": {"open": "09:00", "close": "18:00"}, "sat": {"open": "09:00", "close": "18:00"}, "sun": null, "thu": {"open": "09:00", "close": "18:00"}, "tue": {"open": "09:00", "close": "18:00"}, "wed": {"open": "09:00", "close": "18:00"}}
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: homefix_db_wuc1_user
--

COPY public.users (id, phone, name, email, password_hash, role, otp_code, otp_expires_at, phone_verified, fcm_token, is_active, created_at, updated_at, photo_url, email_verified, email_otp_code, email_otp_expires_at, google_id) FROM stdin;
45285854-dcb2-4d00-9773-ed83b1edc695	9999999999	Default Admin	admin@homefixlive.local	$2a$06$RIN30UhPO.N0X6OAQdvWNe.5ETQTZiNHUGDaDbruaTEm5hiQkr4du	admin	\N	\N	t	\N	t	2026-08-29 06:07:57.379883+00	2026-08-29 06:07:57.379883+00	\N	f	\N	\N	\N
93ab4e3a-1ba5-40a1-8769-ef23269ee293	9999999998	Finance Admin	finance@homefixlive.com	$2a$10$REPLACE_WITH_REAL_BCRYPT_HASH	finance	\N	\N	t	\N	t	2026-08-29 06:08:10.849632+00	2026-08-29 06:08:10.849632+00	\N	t	\N	\N	\N
dc3f702c-b385-4c27-9057-0325c0b5013d	8828404311	Pratiksha	yadavpratiksha488@gmail.com	$2a$10$78QvI6xQS7BUwZOdDvFI7OjB8vV/qarx2pvJZYi3xZ0NfNeLx6j7C	customer	\N	\N	f	cc2-XAGoTLuLz9p6J7m7OT:APA91bEXfcZzfsYTFbEhuZ2nhz6RYcGI75S-Zp7R_4RMRUUYsmjUgCodjVjx2h73vdqhkX63wVZyBYdxEBF4nj7G5iO_vUQ4Gik11hnUp_sy6avyB0FTuCk	t	2026-08-29 06:36:39.545435+00	2026-08-29 08:30:54.474892+00	\N	f	945252	2026-08-29 06:46:39.878198+00	\N
8ce31a51-34d2-45ac-bbdd-0069413f6b3a	8080547253	Anuj	anuj123@gmail.com	$2a$10$bflVvAAPFmf6xcQPLSnuTOT7Zd74sDDLyrWsovj4cGqqAxAzO3fpy	technician	\N	\N	f	dL9FNnRWXTOjdHk-sUZe8X:APA91bFjJR--TMssZhho8F3vKI08kRcUUOQb_-lia7DRHz0zdDSgBo-q2PI__GzmSX8nOdzFFOP7ah7uyyElAchFjjP9n5HLlZYOXbyP5eoSVCpCETF5KX4	t	2026-08-29 07:19:48.11591+00	2026-08-29 10:55:12.711842+00	\N	f	698893	2026-08-29 07:29:48.433876+00	\N
5978c7ed-c201-40f9-ac16-08fcb5d81431	9920157777	Uday	uday@gmail.com	$2a$10$K9w5KPXa/xASKqbmUouhDeE67oBHNDu1GwrUEDF1Ea4HPVdBKqpBK	customer	\N	\N	f	fd_xHlHVSVSC-4jIquGBLm:APA91bFwMt5MbZ5ZS--vn7Yf3yh1BONvHevikVe7L942--nfdF_j3a1czfeJ0kyQAfnRfWutQrmiq3QDSDVHFw8mXN-KQxZC8PIMwn1BfG079xo8MjOjfF8	t	2026-08-29 07:44:01.521287+00	2026-08-29 08:33:05.355216+00	\N	f	689508	2026-08-29 07:54:01.869683+00	\N
3be2026d-ea02-43f3-bc41-e0b3e9bb133c	8828404318	Pratiksha	pratikshayadav7777@gmail.com	$2a$10$33EhL2GuDYOAgGEe4pq.8.RcwGbpZAWTwlpb.Sba38KndpKpeq.s2	customer	\N	\N	f	erVrAt3mQOO819nvwBk5p1:APA91bHnOn33U-XUdxTQXb-Lv9ltQpNaUuNXabinMQqTkgy_tuLz-xpeUUR7UI1QSW4NqATt0HLhzM-1Wp7b5oHXADRaxEjgRe-9KLoDWIkuK-T5_dzJiSE	t	2026-08-29 06:14:05.543702+00	2026-09-07 02:48:36.416837+00	\N	f	840589	2026-08-29 06:25:09.906237+00	108677464958948456973
aa7028e7-32bb-4752-b354-8adfcf4845d1	9960002836	Jayashri	Jayashrimane17@gmail.com	$2a$10$sd5CMr8AAhvOX6aplCvcW.jRQVnkZjrgrsEmSqlVQVd6xb93vChQ6	customer	\N	\N	f	cerUGbh6TtStRWy6YPc0B7:APA91bH-mdyzoDbpGGE1daJPd2qkx-ubgeWQ6d9nqhnYz_yD9SVosqOAgaeU3DC0tPj62sFFFQ-BpluU4Ar_hC4NehB1rGAJGKtuKn00wcZ9qUEkRfBO4jQ	t	2026-08-30 13:20:13.497116+00	2026-08-30 13:20:13.797953+00	\N	f	860242	2026-08-30 13:30:13.796931+00	\N
3e09db72-8f82-49c5-81b4-b95be21ea46f	8080542753	Pradnya	adawadepradnya01@gmail.com	$2a$10$RzRPXxg15AuQR3ALBTX/3.QhDMx2TARX5EKqOJgmsopQ6htcX5PVm	technician	\N	\N	f	eOT5CHMNTru8nxKeaMV0Or:APA91bH4aWIgkAoVWxidYz-8tSs8dyD_4JyYQtVM5M5LSO0NRWoPxpC0h6Tdn4PZoZ5ioid6GJXZD_ZnGTM4uRHPFKhxGhSY7hqHZEq1q5ts6YOVb1H-tzw	t	2026-08-29 06:38:14.442947+00	2026-08-29 06:39:37.351076+00	\N	f	668157	2026-08-29 06:48:14.694886+00	\N
35bb12a9-b2c6-4f77-b383-307759714318	80805478623	Pratiksha	pratiksha10@gmail.com	$2a$10$JEsJlxQBOafbDyGE.g9k5OsMjCaIXWJMXYG7JqLXwWILG9eoaePM.	technician	\N	\N	f	fltrdrU1SVS1BSo2FUzvTz:APA91bHGo2fyeOZAkqR0W_MgDVwvytRyU3x9dbnVLCKURkJCL7Cc7vhlBa4rwBoF6UNcdk8epkFf9cWCCdOGZVwkPnjn-b1ZwlZvm-Z3dAwryIN6ZjVlz0E	t	2026-08-31 06:58:19.678995+00	2026-09-07 09:27:52.357794+00	\N	f	024158	2026-08-31 07:08:20.086352+00	\N
064fad8e-000a-4ed1-a447-160afea13815	8080542759	Rani	rani13@gmail.com	$2a$10$T46CAx1pTWd6Yk3HY503vuJnH/Nojtbe1Jk7OiheDuBpPLbSSC3pe	customer	\N	\N	f	\N	t	2026-09-01 10:57:57.77389+00	2026-09-01 10:57:58.00045+00	\N	f	318653	2026-09-01 11:07:58.000021+00	\N
ef023969-5324-493a-ad92-0ce013f4a1ca	9821190159	Abhishek Gadge	akgadge21@gmail.com	$2a$10$U2C18XqLaqEkX9GVS884HucE/ItoCZzHQ/.jy6biCyCieyEf5ejnO	customer	\N	\N	f	e7BDEE0tQVy31NKTE9zSLp:APA91bGdhEjb1ZLBamOZFVu_gcK2t2ARIaqMd-BhC3-t74FuVve9xiyVn11OqCsaY5snwCiaXKd3wbrupELQcQrqXXs-fcPidNTzTKl7ibBC14uXcNyFtdg	t	2026-08-29 08:43:32.709565+00	2026-09-02 14:29:56.569488+00	\N	f	446044	2026-08-29 08:53:32.937272+00	\N
aebfbed2-7205-437b-9045-65d1b0240e6a	8080542751	Pradnya	pradnyaadawade20@gmail.com	$2a$10$v0dPACk60D18.IzmQvZiwOCu80qB6z1PWdm0tRxwouR.D9Aup4TYS	customer	\N	\N	f	cYoSgu99QMW3JR_Zv7B7ez:APA91bF1-QAG50RchMm8V__xCOM_IkchhFlvt_oLy3qXihKf77OYomTT5xf7rhGvyeo5rQMwZPZDkg93aUpQdXCezZMvM-8aREJSoxnpl0dk8eBGuYaGBGs	t	2026-08-29 06:14:22.043034+00	2026-09-07 10:58:38.575792+00	\N	f	529257	2026-08-29 06:44:16.523855+00	100390284172673929324
a5bcbdcb-965d-4e7e-843b-7e16cfd43eb4	8080547251	Pradnya	pradnya13@gmail.com	$2a$10$brC/vaqcpdwxpSP/QFc2v.8DEznZlPazIlBuncZljgB7i5V5xacmq	technician	\N	\N	f	dna8AHlBTESa4sbshm3oXf:APA91bGEWuqIE3Gv-8NA_z8Yxr_lN8XUK1bxqV1JtosVNE2DLAXBu_Zmg_3_gXfbF7xz9v54bvu6ak_p0wJHaGHNoWoYz9X-8wY4QJkwFDjHOWl8HCZY7kY	t	2026-08-29 08:08:59.519844+00	2026-08-31 11:02:00.166561+00	\N	f	599795	2026-08-29 08:18:59.91492+00	\N
4f3d12f3-d8a6-4c97-8016-2d44b252426f	8356854575	Ajay Subhash Rathod	ajayrathod5585@gmail.com	$2a$10$GJYugHppwMiehtHIu3vzveBdRj6/voqE36NzhbrqQUUMQ8ZGxjocu	customer	\N	\N	f	dqsAWrHaSU-pZeF2z2E-ni:APA91bG--NdtYC6TbHAb0k_I3UpImNjAAvxBquvjiYYCANQpiIxN4cXPWSUzx4tFHpnNTt8fNQnkXEvrThA0rKp19i42Dr8FTBtZ5whLD9o0CTps0DvE6o4	t	2026-08-29 07:40:14.515108+00	2026-09-03 08:20:10.261227+00	\N	f	019115	2026-08-29 07:50:14.797495+00	\N
9dd63068-5ba2-487e-ab79-aa0bb4f686f5	84509391818	jyoti	jyoti123@gmail.com	$2a$10$7Ap0hSriMMt87VNmi2bRA.PO8WAz5rEcpxp.ait2VSr1/sQPJZ/zO	customer	\N	\N	f	\N	t	2026-09-04 02:32:37.209321+00	2026-09-04 02:32:37.410156+00	\N	f	125080	2026-09-04 02:42:37.409684+00	\N
\.


--
-- Data for Name: wallet_transactions; Type: TABLE DATA; Schema: public; Owner: homefix_db_wuc1_user
--

COPY public.wallet_transactions (id, wallet_id, type, amount, reason, reference_id, created_at) FROM stdin;
876dc5e3-04d2-47d3-b086-3924a8700b04	e1eb9541-d73a-4951-bcaa-4fe6f154df3c	credit	322.19	booking_earning	89e44e59-cf5c-4a55-8e50-8b4d7c56aeec	2026-08-29 07:24:26.451772+00
\.


--
-- Data for Name: wallets; Type: TABLE DATA; Schema: public; Owner: homefix_db_wuc1_user
--

COPY public.wallets (id, user_id, balance, updated_at) FROM stdin;
e1eb9541-d73a-4951-bcaa-4fe6f154df3c	8ce31a51-34d2-45ac-bbdd-0069413f6b3a	322.19	2026-08-29 07:24:26.451772+00
\.


--
-- Name: booking_service_seq; Type: SEQUENCE SET; Schema: public; Owner: homefix_db_wuc1_user
--

SELECT pg_catalog.setval('public.booking_service_seq', 1086, true);


--
-- Name: addresses addresses_pkey; Type: CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.addresses
    ADD CONSTRAINT addresses_pkey PRIMARY KEY (id);


--
-- Name: ai_diagnosis_messages ai_diagnosis_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.ai_diagnosis_messages
    ADD CONSTRAINT ai_diagnosis_messages_pkey PRIMARY KEY (id);


--
-- Name: ai_diagnosis_sessions ai_diagnosis_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.ai_diagnosis_sessions
    ADD CONSTRAINT ai_diagnosis_sessions_pkey PRIMARY KEY (id);


--
-- Name: audit_logs audit_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_pkey PRIMARY KEY (id);


--
-- Name: booking_estimate_items booking_estimate_items_pkey; Type: CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.booking_estimate_items
    ADD CONSTRAINT booking_estimate_items_pkey PRIMARY KEY (id);


--
-- Name: booking_estimates booking_estimates_pkey; Type: CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.booking_estimates
    ADD CONSTRAINT booking_estimates_pkey PRIMARY KEY (id);


--
-- Name: booking_job_photos booking_job_photos_pkey; Type: CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.booking_job_photos
    ADD CONSTRAINT booking_job_photos_pkey PRIMARY KEY (id);


--
-- Name: booking_messages booking_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.booking_messages
    ADD CONSTRAINT booking_messages_pkey PRIMARY KEY (id);


--
-- Name: booking_status_history booking_status_history_pkey; Type: CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.booking_status_history
    ADD CONSTRAINT booking_status_history_pkey PRIMARY KEY (id);


--
-- Name: bookings bookings_pkey; Type: CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT bookings_pkey PRIMARY KEY (id);


--
-- Name: bookings bookings_service_code_unique; Type: CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT bookings_service_code_unique UNIQUE (service_code);


--
-- Name: categories categories_name_key; Type: CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_name_key UNIQUE (name);


--
-- Name: categories categories_pkey; Type: CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (id);


--
-- Name: cms_announcements cms_announcements_pkey; Type: CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.cms_announcements
    ADD CONSTRAINT cms_announcements_pkey PRIMARY KEY (id);


--
-- Name: cms_banners cms_banners_pkey; Type: CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.cms_banners
    ADD CONSTRAINT cms_banners_pkey PRIMARY KEY (id);


--
-- Name: cms_faqs cms_faqs_pkey; Type: CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.cms_faqs
    ADD CONSTRAINT cms_faqs_pkey PRIMARY KEY (id);


--
-- Name: cms_pages cms_pages_key_key; Type: CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.cms_pages
    ADD CONSTRAINT cms_pages_key_key UNIQUE (key);


--
-- Name: cms_pages cms_pages_pkey; Type: CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.cms_pages
    ADD CONSTRAINT cms_pages_pkey PRIMARY KEY (id);


--
-- Name: consultations consultations_pkey; Type: CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.consultations
    ADD CONSTRAINT consultations_pkey PRIMARY KEY (id);


--
-- Name: dispute_evidence dispute_evidence_pkey; Type: CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.dispute_evidence
    ADD CONSTRAINT dispute_evidence_pkey PRIMARY KEY (id);


--
-- Name: disputes disputes_pkey; Type: CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.disputes
    ADD CONSTRAINT disputes_pkey PRIMARY KEY (id);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: payments payments_pkey; Type: CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_pkey PRIMARY KEY (id);


--
-- Name: reviews reviews_booking_id_key; Type: CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_booking_id_key UNIQUE (booking_id);


--
-- Name: reviews reviews_pkey; Type: CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_pkey PRIMARY KEY (id);


--
-- Name: spare_part_orders spare_part_orders_pkey; Type: CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.spare_part_orders
    ADD CONSTRAINT spare_part_orders_pkey PRIMARY KEY (id);


--
-- Name: spare_part_stock_movements spare_part_stock_movements_pkey; Type: CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.spare_part_stock_movements
    ADD CONSTRAINT spare_part_stock_movements_pkey PRIMARY KEY (id);


--
-- Name: spare_parts spare_parts_pkey; Type: CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.spare_parts
    ADD CONSTRAINT spare_parts_pkey PRIMARY KEY (id);


--
-- Name: spare_parts spare_parts_sku_key; Type: CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.spare_parts
    ADD CONSTRAINT spare_parts_sku_key UNIQUE (sku);


--
-- Name: suppliers suppliers_pkey; Type: CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.suppliers
    ADD CONSTRAINT suppliers_pkey PRIMARY KEY (id);


--
-- Name: technicians technicians_pkey; Type: CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.technicians
    ADD CONSTRAINT technicians_pkey PRIMARY KEY (id);


--
-- Name: technicians technicians_user_id_key; Type: CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.technicians
    ADD CONSTRAINT technicians_user_id_key UNIQUE (user_id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_google_id_key; Type: CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_google_id_key UNIQUE (google_id);


--
-- Name: users users_phone_key; Type: CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_phone_key UNIQUE (phone);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: wallet_transactions wallet_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.wallet_transactions
    ADD CONSTRAINT wallet_transactions_pkey PRIMARY KEY (id);


--
-- Name: wallets wallets_pkey; Type: CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.wallets
    ADD CONSTRAINT wallets_pkey PRIMARY KEY (id);


--
-- Name: wallets wallets_user_id_key; Type: CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.wallets
    ADD CONSTRAINT wallets_user_id_key UNIQUE (user_id);


--
-- Name: idx_audit_logs_admin; Type: INDEX; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE INDEX idx_audit_logs_admin ON public.audit_logs USING btree (admin_user_id);


--
-- Name: idx_audit_logs_entity; Type: INDEX; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE INDEX idx_audit_logs_entity ON public.audit_logs USING btree (entity_type, entity_id);


--
-- Name: idx_booking_estimate_items_estimate_id; Type: INDEX; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE INDEX idx_booking_estimate_items_estimate_id ON public.booking_estimate_items USING btree (estimate_id);


--
-- Name: idx_booking_estimates_booking_id; Type: INDEX; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE INDEX idx_booking_estimates_booking_id ON public.booking_estimates USING btree (booking_id);


--
-- Name: idx_booking_job_photos_booking_id; Type: INDEX; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE INDEX idx_booking_job_photos_booking_id ON public.booking_job_photos USING btree (booking_id, photo_type);


--
-- Name: idx_booking_messages_booking_id; Type: INDEX; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE INDEX idx_booking_messages_booking_id ON public.booking_messages USING btree (booking_id, created_at);


--
-- Name: idx_bookings_customer; Type: INDEX; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE INDEX idx_bookings_customer ON public.bookings USING btree (customer_id);


--
-- Name: idx_bookings_customer_technician; Type: INDEX; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE INDEX idx_bookings_customer_technician ON public.bookings USING btree (customer_id, technician_id);


--
-- Name: idx_bookings_payment_status; Type: INDEX; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE INDEX idx_bookings_payment_status ON public.bookings USING btree (payment_status);


--
-- Name: idx_bookings_status; Type: INDEX; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE INDEX idx_bookings_status ON public.bookings USING btree (status);


--
-- Name: idx_bookings_technician; Type: INDEX; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE INDEX idx_bookings_technician ON public.bookings USING btree (technician_id);


--
-- Name: idx_bookings_warranty_claim_of; Type: INDEX; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE INDEX idx_bookings_warranty_claim_of ON public.bookings USING btree (warranty_claim_of) WHERE (warranty_claim_of IS NOT NULL);


--
-- Name: idx_bookings_warranty_expires_at; Type: INDEX; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE INDEX idx_bookings_warranty_expires_at ON public.bookings USING btree (warranty_expires_at) WHERE (warranty_enabled = true);


--
-- Name: idx_consultations_ai_diagnosis; Type: INDEX; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE INDEX idx_consultations_ai_diagnosis ON public.consultations USING btree (ai_diagnosis_session_id);


--
-- Name: idx_consultations_customer; Type: INDEX; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE INDEX idx_consultations_customer ON public.consultations USING btree (customer_id);


--
-- Name: idx_consultations_scheduled_due; Type: INDEX; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE INDEX idx_consultations_scheduled_due ON public.consultations USING btree (scheduled_at) WHERE ((status)::text = 'confirmed'::text);


--
-- Name: idx_consultations_status; Type: INDEX; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE INDEX idx_consultations_status ON public.consultations USING btree (status);


--
-- Name: idx_consultations_technician; Type: INDEX; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE INDEX idx_consultations_technician ON public.consultations USING btree (technician_id);


--
-- Name: idx_disputes_booking; Type: INDEX; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE INDEX idx_disputes_booking ON public.disputes USING btree (booking_id);


--
-- Name: idx_disputes_status; Type: INDEX; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE INDEX idx_disputes_status ON public.disputes USING btree (status);


--
-- Name: idx_notifications_user; Type: INDEX; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE INDEX idx_notifications_user ON public.notifications USING btree (user_id);


--
-- Name: idx_payments_razorpay_order_id; Type: INDEX; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE INDEX idx_payments_razorpay_order_id ON public.payments USING btree (razorpay_order_id);


--
-- Name: idx_payments_transaction_ref; Type: INDEX; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE UNIQUE INDEX idx_payments_transaction_ref ON public.payments USING btree (transaction_ref);


--
-- Name: idx_reviews_consultation; Type: INDEX; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE INDEX idx_reviews_consultation ON public.reviews USING btree (consultation_id);


--
-- Name: idx_spare_parts_category; Type: INDEX; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE INDEX idx_spare_parts_category ON public.spare_parts USING btree (category_id);


--
-- Name: idx_technicians_approval_status; Type: INDEX; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE INDEX idx_technicians_approval_status ON public.technicians USING btree (approval_status);


--
-- Name: idx_technicians_category; Type: INDEX; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE INDEX idx_technicians_category ON public.technicians USING btree (category_id);


--
-- Name: reviews trg_update_technician_rating; Type: TRIGGER; Schema: public; Owner: homefix_db_wuc1_user
--

CREATE TRIGGER trg_update_technician_rating AFTER INSERT ON public.reviews FOR EACH ROW EXECUTE FUNCTION public.update_technician_rating();


--
-- Name: addresses addresses_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.addresses
    ADD CONSTRAINT addresses_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: ai_diagnosis_messages ai_diagnosis_messages_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.ai_diagnosis_messages
    ADD CONSTRAINT ai_diagnosis_messages_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.ai_diagnosis_sessions(id) ON DELETE CASCADE;


--
-- Name: ai_diagnosis_sessions ai_diagnosis_sessions_booking_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.ai_diagnosis_sessions
    ADD CONSTRAINT ai_diagnosis_sessions_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES public.bookings(id);


--
-- Name: ai_diagnosis_sessions ai_diagnosis_sessions_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.ai_diagnosis_sessions
    ADD CONSTRAINT ai_diagnosis_sessions_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.categories(id);


--
-- Name: ai_diagnosis_sessions ai_diagnosis_sessions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.ai_diagnosis_sessions
    ADD CONSTRAINT ai_diagnosis_sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: audit_logs audit_logs_admin_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_admin_user_id_fkey FOREIGN KEY (admin_user_id) REFERENCES public.users(id);


--
-- Name: booking_estimate_items booking_estimate_items_estimate_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.booking_estimate_items
    ADD CONSTRAINT booking_estimate_items_estimate_id_fkey FOREIGN KEY (estimate_id) REFERENCES public.booking_estimates(id) ON DELETE CASCADE;


--
-- Name: booking_estimates booking_estimates_booking_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.booking_estimates
    ADD CONSTRAINT booking_estimates_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES public.bookings(id) ON DELETE CASCADE;


--
-- Name: booking_estimates booking_estimates_technician_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.booking_estimates
    ADD CONSTRAINT booking_estimates_technician_id_fkey FOREIGN KEY (technician_id) REFERENCES public.technicians(id);


--
-- Name: booking_job_photos booking_job_photos_booking_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.booking_job_photos
    ADD CONSTRAINT booking_job_photos_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES public.bookings(id) ON DELETE CASCADE;


--
-- Name: booking_job_photos booking_job_photos_technician_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.booking_job_photos
    ADD CONSTRAINT booking_job_photos_technician_id_fkey FOREIGN KEY (technician_id) REFERENCES public.technicians(id);


--
-- Name: booking_messages booking_messages_booking_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.booking_messages
    ADD CONSTRAINT booking_messages_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES public.bookings(id) ON DELETE CASCADE;


--
-- Name: booking_messages booking_messages_sender_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.booking_messages
    ADD CONSTRAINT booking_messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES public.users(id);


--
-- Name: booking_status_history booking_status_history_booking_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.booking_status_history
    ADD CONSTRAINT booking_status_history_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES public.bookings(id) ON DELETE CASCADE;


--
-- Name: bookings bookings_address_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT bookings_address_id_fkey FOREIGN KEY (address_id) REFERENCES public.addresses(id);


--
-- Name: bookings bookings_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT bookings_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.categories(id);


--
-- Name: bookings bookings_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT bookings_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.users(id);


--
-- Name: bookings bookings_technician_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT bookings_technician_id_fkey FOREIGN KEY (technician_id) REFERENCES public.technicians(id);


--
-- Name: bookings bookings_warranty_claim_of_fkey; Type: FK CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT bookings_warranty_claim_of_fkey FOREIGN KEY (warranty_claim_of) REFERENCES public.bookings(id);


--
-- Name: cms_pages cms_pages_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.cms_pages
    ADD CONSTRAINT cms_pages_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.users(id);


--
-- Name: consultations consultations_ai_diagnosis_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.consultations
    ADD CONSTRAINT consultations_ai_diagnosis_session_id_fkey FOREIGN KEY (ai_diagnosis_session_id) REFERENCES public.ai_diagnosis_sessions(id);


--
-- Name: consultations consultations_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.consultations
    ADD CONSTRAINT consultations_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.categories(id);


--
-- Name: consultations consultations_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.consultations
    ADD CONSTRAINT consultations_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: consultations consultations_escalated_booking_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.consultations
    ADD CONSTRAINT consultations_escalated_booking_id_fkey FOREIGN KEY (escalated_booking_id) REFERENCES public.bookings(id);


--
-- Name: consultations consultations_technician_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.consultations
    ADD CONSTRAINT consultations_technician_id_fkey FOREIGN KEY (technician_id) REFERENCES public.technicians(id);


--
-- Name: dispute_evidence dispute_evidence_dispute_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.dispute_evidence
    ADD CONSTRAINT dispute_evidence_dispute_id_fkey FOREIGN KEY (dispute_id) REFERENCES public.disputes(id) ON DELETE CASCADE;


--
-- Name: dispute_evidence dispute_evidence_uploaded_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.dispute_evidence
    ADD CONSTRAINT dispute_evidence_uploaded_by_fkey FOREIGN KEY (uploaded_by) REFERENCES public.users(id);


--
-- Name: disputes disputes_booking_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.disputes
    ADD CONSTRAINT disputes_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES public.bookings(id) ON DELETE CASCADE;


--
-- Name: disputes disputes_consultation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.disputes
    ADD CONSTRAINT disputes_consultation_id_fkey FOREIGN KEY (consultation_id) REFERENCES public.consultations(id) ON DELETE CASCADE;


--
-- Name: disputes disputes_raised_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.disputes
    ADD CONSTRAINT disputes_raised_by_fkey FOREIGN KEY (raised_by) REFERENCES public.users(id);


--
-- Name: disputes disputes_resolved_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.disputes
    ADD CONSTRAINT disputes_resolved_by_fkey FOREIGN KEY (resolved_by) REFERENCES public.users(id);


--
-- Name: notifications notifications_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: payments payments_booking_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES public.bookings(id) ON DELETE CASCADE;


--
-- Name: payments payments_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: reviews reviews_booking_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES public.bookings(id) ON DELETE CASCADE;


--
-- Name: reviews reviews_consultation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_consultation_id_fkey FOREIGN KEY (consultation_id) REFERENCES public.consultations(id) ON DELETE CASCADE;


--
-- Name: reviews reviews_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.users(id);


--
-- Name: reviews reviews_technician_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_technician_id_fkey FOREIGN KEY (technician_id) REFERENCES public.technicians(id);


--
-- Name: spare_part_orders spare_part_orders_ordered_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.spare_part_orders
    ADD CONSTRAINT spare_part_orders_ordered_by_fkey FOREIGN KEY (ordered_by) REFERENCES public.users(id);


--
-- Name: spare_part_orders spare_part_orders_spare_part_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.spare_part_orders
    ADD CONSTRAINT spare_part_orders_spare_part_id_fkey FOREIGN KEY (spare_part_id) REFERENCES public.spare_parts(id);


--
-- Name: spare_part_orders spare_part_orders_supplier_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.spare_part_orders
    ADD CONSTRAINT spare_part_orders_supplier_id_fkey FOREIGN KEY (supplier_id) REFERENCES public.suppliers(id);


--
-- Name: spare_part_stock_movements spare_part_stock_movements_booking_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.spare_part_stock_movements
    ADD CONSTRAINT spare_part_stock_movements_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES public.bookings(id);


--
-- Name: spare_part_stock_movements spare_part_stock_movements_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.spare_part_stock_movements
    ADD CONSTRAINT spare_part_stock_movements_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: spare_part_stock_movements spare_part_stock_movements_spare_part_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.spare_part_stock_movements
    ADD CONSTRAINT spare_part_stock_movements_spare_part_id_fkey FOREIGN KEY (spare_part_id) REFERENCES public.spare_parts(id) ON DELETE CASCADE;


--
-- Name: spare_parts spare_parts_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.spare_parts
    ADD CONSTRAINT spare_parts_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.categories(id);


--
-- Name: spare_parts spare_parts_supplier_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.spare_parts
    ADD CONSTRAINT spare_parts_supplier_id_fkey FOREIGN KEY (supplier_id) REFERENCES public.suppliers(id);


--
-- Name: technicians technicians_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.technicians
    ADD CONSTRAINT technicians_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.categories(id);


--
-- Name: technicians technicians_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.technicians
    ADD CONSTRAINT technicians_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: wallet_transactions wallet_transactions_wallet_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.wallet_transactions
    ADD CONSTRAINT wallet_transactions_wallet_id_fkey FOREIGN KEY (wallet_id) REFERENCES public.wallets(id) ON DELETE CASCADE;


--
-- Name: wallets wallets_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: homefix_db_wuc1_user
--

ALTER TABLE ONLY public.wallets
    ADD CONSTRAINT wallets_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: FUNCTION armor(bytea); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.armor(bytea) TO homefix_db_wuc1_user;


--
-- Name: FUNCTION armor(bytea, text[], text[]); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.armor(bytea, text[], text[]) TO homefix_db_wuc1_user;


--
-- Name: FUNCTION crypt(text, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.crypt(text, text) TO homefix_db_wuc1_user;


--
-- Name: FUNCTION dearmor(text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.dearmor(text) TO homefix_db_wuc1_user;


--
-- Name: FUNCTION decrypt(bytea, bytea, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.decrypt(bytea, bytea, text) TO homefix_db_wuc1_user;


--
-- Name: FUNCTION decrypt_iv(bytea, bytea, bytea, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.decrypt_iv(bytea, bytea, bytea, text) TO homefix_db_wuc1_user;


--
-- Name: FUNCTION digest(bytea, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.digest(bytea, text) TO homefix_db_wuc1_user;


--
-- Name: FUNCTION digest(text, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.digest(text, text) TO homefix_db_wuc1_user;


--
-- Name: FUNCTION encrypt(bytea, bytea, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.encrypt(bytea, bytea, text) TO homefix_db_wuc1_user;


--
-- Name: FUNCTION encrypt_iv(bytea, bytea, bytea, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.encrypt_iv(bytea, bytea, bytea, text) TO homefix_db_wuc1_user;


--
-- Name: FUNCTION fips_mode(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.fips_mode() TO homefix_db_wuc1_user;


--
-- Name: FUNCTION gen_random_bytes(integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.gen_random_bytes(integer) TO homefix_db_wuc1_user;


--
-- Name: FUNCTION gen_random_uuid(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.gen_random_uuid() TO homefix_db_wuc1_user;


--
-- Name: FUNCTION gen_salt(text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.gen_salt(text) TO homefix_db_wuc1_user;


--
-- Name: FUNCTION gen_salt(text, integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.gen_salt(text, integer) TO homefix_db_wuc1_user;


--
-- Name: FUNCTION hmac(bytea, bytea, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.hmac(bytea, bytea, text) TO homefix_db_wuc1_user;


--
-- Name: FUNCTION hmac(text, text, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.hmac(text, text, text) TO homefix_db_wuc1_user;


--
-- Name: FUNCTION pgp_armor_headers(text, OUT key text, OUT value text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.pgp_armor_headers(text, OUT key text, OUT value text) TO homefix_db_wuc1_user;


--
-- Name: FUNCTION pgp_key_id(bytea); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.pgp_key_id(bytea) TO homefix_db_wuc1_user;


--
-- Name: FUNCTION pgp_pub_decrypt(bytea, bytea); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.pgp_pub_decrypt(bytea, bytea) TO homefix_db_wuc1_user;


--
-- Name: FUNCTION pgp_pub_decrypt(bytea, bytea, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.pgp_pub_decrypt(bytea, bytea, text) TO homefix_db_wuc1_user;


--
-- Name: FUNCTION pgp_pub_decrypt(bytea, bytea, text, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.pgp_pub_decrypt(bytea, bytea, text, text) TO homefix_db_wuc1_user;


--
-- Name: FUNCTION pgp_pub_decrypt_bytea(bytea, bytea); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.pgp_pub_decrypt_bytea(bytea, bytea) TO homefix_db_wuc1_user;


--
-- Name: FUNCTION pgp_pub_decrypt_bytea(bytea, bytea, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.pgp_pub_decrypt_bytea(bytea, bytea, text) TO homefix_db_wuc1_user;


--
-- Name: FUNCTION pgp_pub_decrypt_bytea(bytea, bytea, text, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.pgp_pub_decrypt_bytea(bytea, bytea, text, text) TO homefix_db_wuc1_user;


--
-- Name: FUNCTION pgp_pub_encrypt(text, bytea); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.pgp_pub_encrypt(text, bytea) TO homefix_db_wuc1_user;


--
-- Name: FUNCTION pgp_pub_encrypt(text, bytea, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.pgp_pub_encrypt(text, bytea, text) TO homefix_db_wuc1_user;


--
-- Name: FUNCTION pgp_pub_encrypt_bytea(bytea, bytea); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.pgp_pub_encrypt_bytea(bytea, bytea) TO homefix_db_wuc1_user;


--
-- Name: FUNCTION pgp_pub_encrypt_bytea(bytea, bytea, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.pgp_pub_encrypt_bytea(bytea, bytea, text) TO homefix_db_wuc1_user;


--
-- Name: FUNCTION pgp_sym_decrypt(bytea, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.pgp_sym_decrypt(bytea, text) TO homefix_db_wuc1_user;


--
-- Name: FUNCTION pgp_sym_decrypt(bytea, text, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.pgp_sym_decrypt(bytea, text, text) TO homefix_db_wuc1_user;


--
-- Name: FUNCTION pgp_sym_decrypt_bytea(bytea, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.pgp_sym_decrypt_bytea(bytea, text) TO homefix_db_wuc1_user;


--
-- Name: FUNCTION pgp_sym_decrypt_bytea(bytea, text, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.pgp_sym_decrypt_bytea(bytea, text, text) TO homefix_db_wuc1_user;


--
-- Name: FUNCTION pgp_sym_encrypt(text, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.pgp_sym_encrypt(text, text) TO homefix_db_wuc1_user;


--
-- Name: FUNCTION pgp_sym_encrypt(text, text, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.pgp_sym_encrypt(text, text, text) TO homefix_db_wuc1_user;


--
-- Name: FUNCTION pgp_sym_encrypt_bytea(bytea, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.pgp_sym_encrypt_bytea(bytea, text) TO homefix_db_wuc1_user;


--
-- Name: FUNCTION pgp_sym_encrypt_bytea(bytea, text, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.pgp_sym_encrypt_bytea(bytea, text, text) TO homefix_db_wuc1_user;


--
-- Name: FUNCTION uuid_generate_v1(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.uuid_generate_v1() TO homefix_db_wuc1_user;


--
-- Name: FUNCTION uuid_generate_v1mc(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.uuid_generate_v1mc() TO homefix_db_wuc1_user;


--
-- Name: FUNCTION uuid_generate_v3(namespace uuid, name text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.uuid_generate_v3(namespace uuid, name text) TO homefix_db_wuc1_user;


--
-- Name: FUNCTION uuid_generate_v4(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.uuid_generate_v4() TO homefix_db_wuc1_user;


--
-- Name: FUNCTION uuid_generate_v5(namespace uuid, name text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.uuid_generate_v5(namespace uuid, name text) TO homefix_db_wuc1_user;


--
-- Name: FUNCTION uuid_nil(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.uuid_nil() TO homefix_db_wuc1_user;


--
-- Name: FUNCTION uuid_ns_dns(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.uuid_ns_dns() TO homefix_db_wuc1_user;


--
-- Name: FUNCTION uuid_ns_oid(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.uuid_ns_oid() TO homefix_db_wuc1_user;


--
-- Name: FUNCTION uuid_ns_url(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.uuid_ns_url() TO homefix_db_wuc1_user;


--
-- Name: FUNCTION uuid_ns_x500(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.uuid_ns_x500() TO homefix_db_wuc1_user;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: -; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT ALL ON SEQUENCES TO homefix_db_wuc1_user;


--
-- Name: DEFAULT PRIVILEGES FOR TYPES; Type: DEFAULT ACL; Schema: -; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT ALL ON TYPES TO homefix_db_wuc1_user;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: -; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT ALL ON FUNCTIONS TO homefix_db_wuc1_user;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: -; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT ALL ON TABLES TO homefix_db_wuc1_user;


--
-- PostgreSQL database dump complete
--

\unrestrict GIfUOQVAtZ5htBjr9wWviyY69kRoqnrKOo9wB6FOodHaMpJQhqItJJEqjSGlps7

