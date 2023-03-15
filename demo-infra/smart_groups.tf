resource "aviatrix_smart_group" "internet" {
  name = "Internet"
  selector {
    match_expressions {
      cidr = "1.0.0.0/8"
    }

    match_expressions {
      cidr = "2.0.0.0/7"
    }

    match_expressions {
      cidr = "4.0.0.0/6"
    }

    match_expressions {
      cidr = "8.0.0.0/7"
    }

    match_expressions {
      cidr = "11.0.0.0/8"
    }

    match_expressions {
      cidr = "12.0.0.0/6"
    }

    match_expressions {
      cidr = "16.0.0.0/4"
    }

    match_expressions {
      cidr = "32.0.0.0/3"
    }

    match_expressions {
      cidr = "64.0.0.0/2"
    }

    match_expressions {
      cidr = "128.0.0.0/2"
    }

    match_expressions {
      cidr = "192.0.0.0/3"
    }

  }
}