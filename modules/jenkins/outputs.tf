output "controller_instance_id" { value = aws_instance.controller.id }
output "agent_instance_id"      { value = aws_instance.agent.id }

output "controller_private_ip"  { value = aws_instance.controller.private_ip }
output "agent_private_ip"       { value = aws_instance.agent.private_ip }
