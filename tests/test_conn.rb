#!/usr/bin/ruby

# Test the conn methods the bindings support

$: << File.dirname(__FILE__)

require 'libvirt'
require 'test_utils.rb'

conn = Libvirt::open("qemu:///system")

cpu_xml = <<EOF
<cpu>
  <arch>x86_64</arch>
  <model>athlon</model>
</cpu>
EOF

# TESTGROUP: conn.close
conn2 = Libvirt::open("qemu:///system")
expect_too_many_args(conn2, "close", 1)
expect_success(conn2, "no args", "close")

# TESTGROUP: conn.closed?
conn2 = Libvirt::open("qemu:///system")

expect_too_many_args(conn2, "closed?", 1)
expect_success(conn2, "no args", "closed?") {|x| x == false }
conn2.close
expect_success(conn2, "no args", "closed?") {|x| x == true }

# TESTGROUP: conn.type
expect_too_many_args(conn, "type", 1)

expect_success(conn, "no args", "type") {|x| x == "QEMU"}

# TESTGROUP: conn.version
expect_too_many_args(conn, "version", 1)

expect_success(conn, "no args", "version")

# TESTGROUP: conn.libversion
expect_too_many_args(conn, "libversion", 1)

expect_success(conn, "no args", "libversion")

# TESTGROUP: conn.hostname
expect_too_many_args(conn, "hostname", 1)

expect_success(conn, "no args", "hostname")

# TESTGROUP: conn.uri
expect_too_many_args(conn, "uri", 1)

expect_success(conn, "no args", "uri") {|x| x == "qemu:///system" }

# TESTGROUP: conn.max_vcpus
expect_too_many_args(conn, "max_vcpus", 'kvm', 1)
expect_fail(conn, Libvirt::RetrieveError, "invalid arg", "max_vcpus", "foo")

expect_success(conn, "no args", "max_vcpus")
expect_success(conn, "nil arg", "max_vcpus")
expect_success(conn, "kvm arg", "max_vcpus")
expect_success(conn, "qemu arg", "max_vcpus")

# TESTGROUP: conn.node_get_info
expect_too_many_args(conn, "node_get_info", 1)

expect_success(conn, "no args", "node_get_info")

begin
  # TESTGROUP: conn.node_free_memory
  expect_too_many_args(conn, "node_free_memory", 1)

  conn.node_free_memory
  puts_ok "conn.node_free_memory no args"
rescue Libvirt::RetrieveError
  puts_skipped "conn.node_free_memory not supported on this host"
rescue NoMethodError
  puts_skipped "conn.node_free_memory does not exist"
end

begin
  # TESTGROUP: conn.node_cells_free_memory
  expect_too_many_args(conn, "node_cells_free_memory", 1, 2, 3)
  expect_invalid_arg_type(conn, "node_cells_free_memory", 'start')
  expect_invalid_arg_type(conn, "node_cells_free_memory", 0, 'end')

  cell_mem = conn.node_cells_free_memory
  puts_ok "conn.node_cells_free_memory no args = "
  cell_mem = conn.node_cells_free_memory(0)
  puts_ok "conn.node_cells_free_memory(0) = "
  cell_mem = conn.node_cells_free_memory(0, 1)
  puts_ok "conn.node_cells_free_memory(0, 1) = "
rescue Libvirt::RetrieveError
  puts_skipped "conn.node_cells_free_memory not supported on this host"
rescue NoMethodError
  puts_skipped "conn.node_cells_free_memory does not exist"
end

# TESTGROUP: conn.node_get_security_model
expect_too_many_args(conn, "node_get_security_model", 1)
expect_success(conn, "no args", "node_get_security_model")

# TESTGROUP: conn.encrypted?
expect_too_many_args(conn, "encrypted?", 1)
expect_success(conn, "no args", "encrypted?")

# TESTGROUP: conn.secure?
expect_too_many_args(conn, "secure?", 1)
expect_success(conn, "no args", "secure?") {|x| x == true}

# TESTGROUP: conn.capabilities
expect_too_many_args(conn, "capabilities", 1)
expect_success(conn, "no args", "capabilities")

# TESTGROUP: conn.compare_cpu
expect_too_many_args(conn, "compare_cpu", 1, 2, 3)
expect_too_few_args(conn, "compare_cpu")
expect_invalid_arg_type(conn, "compare_cpu", 1)
expect_invalid_arg_type(conn, "compare_cpu", "hello", 'bar')
expect_fail(conn, Libvirt::RetrieveError, "invalid XML", "compare_cpu", "hello")
expect_success(conn, "CPU XML", "compare_cpu", cpu_xml)

# TESTGROUP: conn.baseline_cpu
expect_too_many_args(conn, "baseline_cpu", 1, 2, 3)
expect_too_few_args(conn, "baseline_cpu")
expect_invalid_arg_type(conn, "baseline_cpu", 1)
expect_invalid_arg_type(conn, "baseline_cpu", [], "foo")
expect_fail(conn, ArgumentError, "empty array", "baseline_cpu", [])
expect_success(conn, "CPU XML", "baseline_cpu", [cpu_xml])

# TESTGROUP: conn.domain_event_register_any
dom_event_callback_proc = lambda {|conn, dom, event, detail, opaque|
}

def dom_event_callback_symbol(conn, dom, event, detail, opaque)
end

expect_too_many_args(conn, "domain_event_register_any", 1, 2, 3, 4, 5)
expect_too_few_args(conn, "domain_event_register_any")
expect_too_few_args(conn, "domain_event_register_any", 1)
expect_invalid_arg_type(conn, "domain_event_register_any", "hello", 1)
expect_invalid_arg_type(conn, "domain_event_register_any", Libvirt::Connect::DOMAIN_EVENT_ID_LIFECYCLE, 1)
expect_invalid_arg_type(conn, "domain_event_register_any", Libvirt::Connect::DOMAIN_EVENT_ID_LIFECYCLE, dom_event_callback_proc, 1)
expect_fail(conn, ArgumentError, "invalid event ID", "domain_event_register_any", 456789, dom_event_callback_proc)

callbackID = expect_success(conn, "eventID and proc", "domain_event_register_any", Libvirt::Connect::DOMAIN_EVENT_ID_LIFECYCLE, dom_event_callback_proc)
conn.domain_event_deregister_any(callbackID)

callbackID = expect_success(conn, "eventID and symbol", "domain_event_register_any", Libvirt::Connect::DOMAIN_EVENT_ID_LIFECYCLE, :dom_event_callback_symbol)
conn.domain_event_deregister_any(callbackID)

callbackID = expect_success(conn, "eventID, proc, nil domain", "domain_event_register_any", Libvirt::Connect::DOMAIN_EVENT_ID_LIFECYCLE, dom_event_callback_proc, nil)
conn.domain_event_deregister_any(callbackID)

callbackID = expect_success(conn, "eventID, proc, nil domain, opaque", "domain_event_register_any", Libvirt::Connect::DOMAIN_EVENT_ID_LIFECYCLE, dom_event_callback_proc, nil, "opaque user data")
conn.domain_event_deregister_any(callbackID)

# TESTGROUP: conn.domain_event_deregister_any
dom_event_callback_proc = lambda {|conn, dom, event, detail, opaque|
}

callbackID = conn.domain_event_register_any(Libvirt::Connect::DOMAIN_EVENT_ID_LIFECYCLE, dom_event_callback_proc)

expect_too_many_args(conn, "domain_event_deregister_any", 1, 2)
expect_too_few_args(conn, "domain_event_deregister_any")
expect_invalid_arg_type(conn, "domain_event_deregister_any", "hello")

expect_success(conn, "callbackID", "domain_event_deregister_any", callbackID)

# TESTGROUP: conn.domain_event_register
dom_event_callback_proc = lambda {|conn, dom, event, detail, opaque|
}

def dom_event_callback_symbol(conn, dom, event, detail, opaque)
end

expect_too_many_args(conn, "domain_event_register", 1, 2, 3)
expect_too_few_args(conn, "domain_event_register")
expect_invalid_arg_type(conn, "domain_event_register", "hello")

expect_success(conn, "proc", "domain_event_register", dom_event_callback_proc)
conn.domain_event_deregister

expect_success(conn, "symbol", "domain_event_register", :dom_event_callback_symbol)
conn.domain_event_deregister

expect_success(conn, "proc and opaque", "domain_event_register", dom_event_callback_proc, "opaque user data")
conn.domain_event_deregister

# TESTGROUP: conn.domain_event_deregister
dom_event_callback_proc = lambda {|conn, dom, event, detail, opaque|
}

conn.domain_event_register(dom_event_callback_proc)

expect_too_many_args(conn, "domain_event_deregister", 1)
expect_success(conn, "no args", "domain_event_deregister")

conn.close

finish_tests
