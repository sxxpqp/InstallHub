package main

import (
	// "fmt"
	"os"
	"os/exec"
	// "log"
	// "strconv"
)

// 执行 shell 命令的函数
func runShellCommand(command string, args ...string) error {
	cmd := exec.Command(command, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func main() {

	runShellCommand("sudo", "-i")
	runShellCommand("ls", "-l")
	runShellCommand("sudo", "docker", "ps")

}
