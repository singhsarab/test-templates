using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Documents;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Navigation;
using System.Windows.Shapes;

namespace WinAppDriverTestWizard
{
    /// <summary>
    /// Interaction logic for WizardUI.xaml
    /// </summary>
    public partial class WizardUI : Window
    {
        public TemplateConfig Config { get; }
        public WizardUI()
        {
            InitializeComponent();
            Config = new TemplateConfig();
            DataContext = Config; 
        }

        private void OnCancel(object sender, EventArgs args)
        {
            // TODO: Clear the Config instance and return to VS new project
        }

        private void OnPreceed(object sender, EventArgs args)
        {
            // TODO: Give Config to TestWizard, let wizard create a new template
        }
    }

    /// <summary>
    /// Configuration of the test template
    /// </summary>
    public class TemplateConfig
    {
        public string TargetFramework { get; set; }
        public string IPAddress { get; set; } = "127.0.0.1";
        public string PortNumber { get; set; } = "4723";
    }
}
