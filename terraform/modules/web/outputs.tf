output "alb_dns" { value = aws_lb.this.dns_name }

output "alb_arn_suffix" { value = aws_lb.this.arn_suffix }
output "tg_arn_suffix" { value = aws_lb_target_group.app.arn_suffix }
output "asg_name" { value = aws_autoscaling_group.app.name }
